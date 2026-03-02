module Plugins
  module Queries
    module Object
      def self.included(base)
        base.include ::Plugins.decorators.method_annotations
        base.include ::Plugins.decorators.method_decorators
        base.include ::Plugins::Decorators.method_decorators
        base.include ::Plugins.decorators.smart_send
        base.include ::Plugins::Decorators.registered
        base.extend ClassMethods
        base.include InstanceMethods

        base.attr_accessor :query

        base.inheritable_class_attribute :query_type, :models, :query_methods,  :tags
        base.query_type = base.name.demodulize.underscore
        base.models = Set.new
        base.query_methods = {}
        base.tags = []

        base.define_method_decorator :define_query do |method_name, original, *args, block, **_opts|
          self.query_methods[method_name]= "#{query_type}_#{method_name}"
          result = original.call(*args, &block)

          valid_query_object!(result) if result

          self.query = result
          result
        end

        base.query_object do |query|
          (defined?(::ActiveRecord::Relation) && query.is_a?(::ActiveRecord::Relation)) ||
            (defined?(::ActiveRecord::Base) && query.is_a?(::ActiveRecord::Base)) ||
            (defined?(::Ransack::Search) && query.is_a?(::Ransack::Search))
        end

        ::Plugins::Queries::Object << base
      end

      module ClassMethods
        def inherited(subclass)
          super(subclass) if defined?(super)
          subclass.query_type = subclass.name.demodulize.underscore
          ::Plugins::Queries::Object << subclass
        end

        def query_object method_name=nil, &block
          method_name ||= "#{SecureRandom.hex(8)}_query_object"
          annotate_method(method_name, query_object: true, &block)
        end

      end

      module InstanceMethods
        def initialize(query = nil)
          valid_query_object!(query) if query

          self.query = query
        end

        def method_missing(method_name, *args, &block)
          if query && query.respond_to?(method_name)
            return query.public_send(method_name, *args, &block)
          end

          super
        end

        def respond_to_missing?(method_name, include_private = false)
          (query && query.respond_to?(method_name, include_private)) || super
        end

        private

        def valid_query_object?(value)
          self.class.methods_annotated_with(:query_object, true).any? do |method_name|
            send(method_name, value)
          end
        end

        def valid_query_object!(value)
          return true if valid_query_object?(value)

          raise ArgumentError, "Invalid query object for #{self.class.name}"
        end

      end
    end
  end
end
