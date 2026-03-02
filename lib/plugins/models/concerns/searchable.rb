module Plugins
  module Models
    module Concerns
      module Searchable

        extend ::Plugins::Decorators::ConfigBuilder
        include ::Plugins.decorators.registered

        included do
          scope :generic_search, -> (search, advanced_search={}, sort= nil, o=nil){
            qr ={['generic', o || 'cont'].join('_') => search}
            if (advanced_search.is_a? Hash)
              qr.merge!(advanced_search)
            end
            res = ransack(qr)
            if sort.present?
              sort = [sort].reject(&:blank?) unless sort.is_a?(Array)
              res.sorts= sort unless sort.empty?
            end
            res.result
          }
        end

        def self.default_options
          {
            query_classes: [],
            default_query_object: proc { self.where.not(id: nil) }
          }
        end

        module ClassMethods

          def searchable **opts, &block
            default_opts = ::Plugins::Models::Concerns::Searchable.default_options
            ::Plugins::Models::Concerns::Searchable.plugins_config.setup(self, "searchable_config", opts, default_opts,
                                                        method_prefix: "searchable", &block)
            ::Plugins::Models::Concerns::Searchable << self
            include DepedencyHooks
            extend Hooks
            unless respond_to?(:searchable_query_wrapper_class)
              inheritable_class_attribute :searchable_query_wrapper_class
            end
            self.searchable_query_wrapper_class = QueryWrapper.build(self, searchable_config)
            scope :generic_search, -> (search, advanced_search={}, sort= nil, o=nil){
              if respond_to?(:ransack)
                qr ={['generic', o || 'cont'].join('_') => search}
                if (advanced_search.is_a? Hash)
                  qr.merge!(advanced_search)
                end
                res = ransack(qr)
                if sort.present?
                  sort = [sort].reject(&:blank?) unless sort.is_a?(Array)
                  res.sorts= sort unless sort.empty?
                end
                res.result
              else
                self
              end
            }
          end
        end

        module DepedencyHooks
          extend ActiveSupport::Concern
          included do
            include ::Plugins.decorators.method_annotations
            include ::Plugins.decorators.inheritables
            include ::Plugins.decorators.hooks
          end
        end

        module Hooks
          def inherited(subclass)
            super(subclass)
            after_class_defined(subclass) do
              ::Plugins::Models::Concerns::Searchable << subclass
            end
          end

          def define_generic_ransack_search *fields
            if respond_to?(:ransack_alias)
              ransack_alias :generic, "#{fields.map(&:to_s).join("_or_")}"
            end
          end

          def define_alias_ransack_search(_alias, *field)
            if respond_to?(:ransack_alias)
              ransack_alias _alias, "#{field}"
            end
          end

          def query(q = nil, &block)
            q ||= searchable_config.default_query_object
            wrapper_class = searchable_query_wrapper_class || QueryWrapper.build(self, searchable_config)
            wrapper = wrapper_class.new(q)

            if block
              wrapper.instance_exec(&block)
            end

            wrapper.query
          end
        end


        class QueryWrapper
          class << self
            def build(model_class, config)
              query_classes = resolve_query_classes(config)
              wrapper_class = Class.new do
                attr_accessor :query

                def initialize(query = nil)
                  self.query = query
                end

              end

              query_classes.each do |query_class|
                query_class.query_methods.each do |actual_name, method_name|
                  method_sym = method_name.to_sym
                  actual_method = actual_name.to_sym

                  wrapper_class.define_method(method_sym) do |*args, **kwargs, &block|
                    query_object = query_class.new(query)
                    call_args = args.dup
                    call_args << kwargs unless kwargs.empty?
                    result = query_object.smart_send(actual_method, call_args, &block)

                    if query_object.query
                      self.query = query_object.query
                    end

                    result
                  end
                end
              end

              wrapper_class
            end

            def resolve_query_classes(config)
              classes = Array(config&.query_classes).compact
              classes = classes.map { |entry| resolve_query_class(entry) }.compact

              classes
            end

            def resolve_query_class(entry)
              case entry
              when Class, Module
                entry
              when String, Symbol
                resolve_from_registry(entry) || entry.to_s.safe_constantize
              end
            end

            def resolve_from_registry(query_type)
              ::Plugins::Queries::Object.registered_classes.find do |klass|
                klass.query_type.to_s == query_type.to_s || klass.name.to_s == query_type.to_s
              end
            rescue StandardError
              nil
            end
          end
        end


      end
    end
  end
end
