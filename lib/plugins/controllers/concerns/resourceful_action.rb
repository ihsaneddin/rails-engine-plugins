module Plugins
  module Controllers
    module Concerns
      module ResourcefulAction
        extend ActiveSupport::Concern

        included do
          class_attribute :resourceful_overrides
          self.resourceful_overrides = Hash.new { |h, k| h[k] = {} }
        end

        module ClassMethods

          def inherited sub
            super(sub)
            sub.resourceful_overrides = Hash.new { |h, k| h[k] = {} }
          end

          def resourceful_for(actions, **opts, &block)
            opts = opts.merge(__resourceful_block__: block) if block
            opts = opts.transform_keys(&:to_sym)

            Array(actions).each do |action|
              action = action.to_sym
              overrides = (resourceful_overrides || {}).dup
              action_overrides = (overrides[action] || {}).dup
              action_overrides.merge!(opts)
              overrides[action] = action_overrides
              self.resourceful_overrides = overrides
            end
          end
        end

        class OverrideContext
          KEYS = [
            :model_klass,
            :resource_context,
            :resource_var_name,
            :attr_accessor_name,
            :query_scope,
            :query_includes,
            :resource_identifier,
            :resource_finder_key,
            :resource_finder,
            :resources_finder,
            :resource_params_attributes,
            :should_paginate,
            :after_fetch_resource
          ].freeze

          def initialize(controller, overrides)
            @controller = controller
            @overrides = overrides
          end

          KEYS.each do |key|
            define_method(key) do |value = nil, &block|
              @overrides[key] = block_given? ? block : value
            end
          end

          def method_missing(name, *args, &block)
            if @controller.respond_to?(name, true)
              @controller.public_send(name, *args, &block)
            else
              super
            end
          end

          def respond_to_missing?(name, include_private = false)
            @controller.respond_to?(name, include_private) || super
          end
        end

        def get_value(key, *args)
          prev = super
          key = key.to_sym
          action = action_name&.to_sym
          return prev unless action

          overrides = self.class.resourceful_overrides[action]
          return prev unless overrides && overrides.key?(key)

          if overrides[:__resourceful_block__]
            @_resourceful_action_overrides ||= {}
            cache = (@_resourceful_action_overrides[action] ||= {})
            if cache.empty?
              ctx = OverrideContext.new(self, cache)
              ctx.instance_exec(&overrides[:__resourceful_block__])
            end
            overrides = overrides.merge(cache)
          end

          value = overrides[key]
          return prev if value.nil?

          if value.is_a?(Proc)
            result = instance_exec(prev, *args, &value)
            return result.nil? ? prev : result
          end

          value
        end
      end
    end
  end
end
