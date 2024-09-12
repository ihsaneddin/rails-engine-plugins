#require 'plugins/configuration/callbacks'

module Plugins
  module Configuration
    module GrapeApi

      mattr_accessor :authenticate
      @@authenticate = -> { nil }

      mattr_accessor :base_api_class
      @@base_api_class= nil

      class << self

        def authenticate! &block
          @@authenticate = block
        end

        def setup &block
          block.arity.zero? ? instance_eval(&block) : yield(self)
        end

        def draw_callbacks &block
          callback_set.draw_callbacks(&block)
        end

      end

      module Pagination

        class << self
          def configure
            yield config
          end

          def config
            @config ||= Configuration.new
          end

          def setup
            configure
          end

          alias :configuration :config
        end

        class Configuration
          attr_accessor :per_page_count

          attr_accessor :total

          attr_accessor :per_page
          attr_accessor :last_page

          attr_accessor :page

          attr_accessor :include_total
          attr_accessor :total_page

          attr_accessor :base_url

          attr_accessor :response_formats

          def configure(&block)
            yield self
          end

          def initialize
            @per_page_count = 50
            @total    = 'Total'
            @per_page = 'Per-Page'
            @page     = nil
            @include_total   = "true"
            @total_page = 'Total-Pages'
            @last_page = "Last-Page"
            @base_url   = nil
            @response_formats = [:json, :xml]
          end

          ['page', 'per_page'].each do |param_name|
            method_name = "#{param_name}_param"
            instance_variable_name = "@#{method_name}"

            define_method method_name do |params = nil, &block|
              if block.is_a?(Proc)
                instance_variable_set(instance_variable_name, block)
                return
              end

              if instance_variable_get(instance_variable_name).nil?
                instance_variable_set(instance_variable_name, (lambda { |p| p[param_name.to_sym] }))
              end

              instance_variable_get(instance_variable_name).call(params)
            end

            define_method "#{method_name}=" do |param|
              if param.is_a?(Symbol) || param.is_a?(String)
                instance_variable_set(instance_variable_name, (lambda { |params| params[param] }))
              else
                raise ArgumentError, "Cannot set page_param option"
              end
            end
          end

          def paginator
            if instance_variable_defined? :@paginator
              @paginator
            else
              set_paginator
            end
          end

          def paginator=(paginator)
            case paginator.to_sym
            when :pagy
              use_pagy
            when :kaminari
              use_kaminari
            when :will_paginate
              use_will_paginate
            else
              raise StandardError, "Unknown paginator: #{paginator}"
            end
          end

          private

          def set_paginator
            conditions = [defined?(Pagy), defined?(Kaminari), defined?(WillPaginate::CollectionMethods)]
            if conditions.compact.size > 1
              Kernel.warn <<-WARNING
              Warning: fbuilder relies on Pagy, Kaminari, or WillPaginate

              Plugins.config.api.configure do |config|
                config.paginator = :kaminari
              end

              WARNING
            elsif defined?(Pagy)
              use_pagy
            elsif defined?(Kaminari)
              use_kaminari
            elsif defined?(WillPaginate::CollectionMethods)
              use_will_paginate
            end
          end

          def use_pagy
            @paginator = :pagy
          end

          def use_kaminari
            require 'kaminari/models/array_extension'
            @paginator = :kaminari
          end

          def use_will_paginate
            WillPaginate::CollectionMethods.module_eval do
              def first_page?() !previous_page end
              def last_page?() !next_page end
            end

            @paginator = :will_paginate
          end
        end

      end

      mattr_accessor :pagination
      @@pagination = Pagination
      mattr_accessor :base_controller
      @@base_controller_name = "base_controller"

      class ApiCallbackSet < Plugins::Configuration::Callbacks::CallbackSet

        CALLBACKS = ['prepend_before_action', 'before_action', 'after_action', 'model_klass', 'resource_identifier', 'resource_finder_key', 'query_scope', 'query_includes', 'after_fetch_resource', 'presenter', 'should_paginate', 'resource_params_attributes']

        def self.draw_callbacks(constraints = {base: Plugins::Configuration.engine_namespace}, &block)
          raise "engine namespace is not provided" unless constraints[:base]
          super constraints, &block
        end

        def self.callback_class
          ApiCallback
        end

      end

      class ApiCallback < Plugins::Configuration::Callbacks::Callback

        def initialize(name, _namespace: [], **_options, &_block)
          super
          @class = "#{@class}_controller"
        end

        def call context
          block = instance_variable_get("@block")
          resourceful_params = context.resourceful_params
          if resourceful_params.keys.include?(name.to_sym)
            value = context.send(name)
            if value.is_a?(Proc)
              if options[:override] == true
                value = block
              else
                if value.is_a?(Plugins::Controllers::Concerns::Resourceful::Blocks)
                  value.blocks << block
                else
                  value = Plugins::Controllers::Concerns::Resourceful::Blocks.new([value, block])
                end
              end
            else
              value = block
            end
            context.set_resource_param(name, value)
          else
            args = options[:args] || []
            context.send name, *args, &block
          end
        end

        def default_class
          Plugins::Configuration::Api.base_controller_name
        end

      end

      mattr_accessor :callback_set
      @@callback_set = ApiCallbackSet

    end
  end
end