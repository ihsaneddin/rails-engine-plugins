module Plugins
  module Models
    module Concerns
      module ApiResource

        DEFAULT_RESOURCE_FINDER = proc { |query, identifier, api| query.find_by!(identifier) }.freeze
        DEFAULT_RESOURCES_FINDER = proc { |query, identifier, api| query.where(identifier) }.freeze
        DEFAULT_QUERY_SCOPE = proc { |query| query }.freeze

        def self.included base
          base.extend ClassMethods
        end

        def self.plugins_config
          ::Plugins::Models::Concerns::Config
        end

        def self.plugins_collection_config
          ::Plugins::Models::Concerns::Config::Collection
        end

        def self.grape_action path: "", method: :get, route_options: {}, description: nil, params: {}, &block
          raise "block is required" unless block_given?
          opts = { path: path, method: method, route_options: {}, params: {}, payload: block }
          ::Plugins::Models::Concerns::Config.build(**opts)
        end

        def self.grape_actions(opts)
          cfg = ::Plugins::Models::Concerns::Config.build(**opts)
          cfg.dynamic_keys!
          cfg
          # resource_actions:grape_actions(
          #     index: grape_action(
          #       path: "",
          #       method: :get,
          #       payload: proc {
          #         presenter records
          #       }
          #     ),
          #     create: grape_action(
          #       path: "",
          #       method: :post,
          #       payload: proc {
          #         presenter records
          #       }
          #     )
          #   ),
          #   resources_actions: grape_actions(
          #     show: grape_action(
          #       path: "",
          #       method: :get,
          #       payload: proc {
          #         presenter record
          #       }
          #     )
          #   ),
        end

        def self.default_options
          {
            use_api_evaluation: false,
            default: false,
            resource_finder: DEFAULT_RESOURCE_FINDER,
            resources_finder: DEFAULT_RESOURCES_FINDER,
            resource_identifier: "id",
            resource_finder_key: "id",
            resource_params_attributes: [],
            new_resource: nil,
            attr_accessor_name: nil,
            query_scope: DEFAULT_QUERY_SCOPE,
            default_query_scope: nil,
            query_includes: nil,
            after_fetch_resource: nil,
            should_paginate: true,
            presenter: "Plugins::Grape::Presenters::Generic",
            resource_actions: plugins_collection_config.build(**{ http_method: "get", params: nil, route_options: {} }),
            collection_actions: plugins_collection_config.build(**{ http_method: "get", params: nil, route_options: {} }),
          }

        end

        def self.default_api_options
          default_options.dup
        end

        def self.deep_dup_option_value(value)
          case value
          when Proc
            value
          when ::Plugins::Models::Concerns::Config
            value.dup
          when Array
            value.map { |entry| deep_dup_option_value(entry) }
          when Hash
            value.transform_values { |entry| deep_dup_option_value(entry) }
          else
            begin
              value.frozen? || value.is_a?(Numeric) || value.is_a?(Symbol) ? value : value.dup
            rescue
              value
            end
          end
        end

        def self.deep_dup_options(options)
          options.transform_values { |value| deep_dup_option_value(value) }
        end

        def self.prune_default_values(config, defaults)
          pruned = config.dup
          _prune_default_values!(pruned, defaults)
        end

        def self._prune_default_values!(config, defaults)
          config.keys.each do |key|
            value = config.values[key]
            default_value = defaults.values[key]

            if value.is_a?(::Plugins::Models::Concerns::Config) && default_value.is_a?(::Plugins::Models::Concerns::Config)
              _prune_default_values!(value, default_value)
              config.remove_key(key) if _equivalent_config?(value, default_value)
            elsif value == default_value
              config.remove_key(key)
            end
          end

          config
        end

        def self._equivalent_config?(left, right)
          return false unless left.class == right.class

          if left.is_a?(::Plugins::Models::Concerns::Config::Collection)
            left.order == right.order && left.values == right.values
          else
            left.values == right.values
          end
        end

        module ClassMethods

          def grape_api_resource *args, &block

            ctx = args[0] || "default"
            opts = args.extract_options!
            from = opts.delete(:from)
            explicit_option_keys = opts.keys

            opts[:context] = ctx

            setup_defaults = ::Plugins::Models::Concerns::ApiResource.deep_dup_options(
              ::Plugins::Models::Concerns::ApiResource.default_options
            )
            if from.present?
              setup_defaults = prepare_inherited_api_resource_config(
                kind: :grape_api_resource,
                context: ctx,
                source: from,
                options: opts,
                defaults: setup_defaults
              )
            end

            declaration_baseline = deferred_api_resource_declaration_baseline(
              :grape_api_resource,
              ctx,
              setup_defaults
            )

            ::Plugins::Models::Concerns::Config.setup(self, "#{ctx}_grape_api_resource_config", opts, setup_defaults,
                                                        method_prefix: "#{ctx}_grape_api_resource", &block)
            record_local_api_resource_context(
              :grape_api_resource,
              ctx,
              baseline: declaration_baseline,
              explicit_option_keys: explicit_option_keys,
              preserve_composed_source: from.present?
            )

            inheritable_class_attribute :default_grape_api_resource_config_context unless respond_to?(:default_grape_api_resource_config_context)
            if send("#{ctx}_grape_api_resource_default")
              self.default_grape_api_resource_config_context= "#{ctx}"
            end

            define_inheritable_singleton_method(:grape_api_resource?) { true }

            include InstanceMethods
            propagate_deferred_api_resource_context(:grape_api_resource, ctx)
          end

          def grape_api_resource_of(ctx=nil)
            ctx ||= try(:default_grape_api_resource_config_context) || "default"
            cfg = _grape_api_resource_config_for(ctx)
            return cfg if cfg

            fallback = try(:default_grape_api_resource_config_context)
            return if fallback.nil? || fallback.to_s == ctx.to_s

            _grape_api_resource_config_for(fallback)
          end

          def _grape_api_resource_config_for(ctx)
            cfg = respond_to?("#{ctx}_grape_api_resource_config") ? send("#{ctx}_grape_api_resource_config") : nil
            cfg.is_a?(::Plugins::Models::Concerns::Config) ? cfg : nil
          end
          private :_grape_api_resource_config_for

          def grape_api_resource?
            false
          end

          def api_resource *args, &block

            ctx = args[0] || "default"
            opts = args.extract_options!
            from = opts.delete(:from)
            explicit_option_keys = opts.keys

            opts[:context] = ctx

            setup_defaults = ::Plugins::Models::Concerns::ApiResource.deep_dup_options(
              ::Plugins::Models::Concerns::ApiResource.default_api_options
            )
            if from.present?
              setup_defaults = prepare_inherited_api_resource_config(
                kind: :api_resource,
                context: ctx,
                source: from,
                options: opts,
                defaults: setup_defaults
              )
            end

            declaration_baseline = deferred_api_resource_declaration_baseline(
              :api_resource,
              ctx,
              setup_defaults
            )

            ::Plugins::Models::Concerns::Config.setup(self, "#{ctx}_api_resource_config", opts, setup_defaults,
                                                        method_prefix: "#{ctx}_api_resource", &block)
            record_local_api_resource_context(
              :api_resource,
              ctx,
              baseline: declaration_baseline,
              explicit_option_keys: explicit_option_keys,
              preserve_composed_source: from.present?
            )

            inheritable_class_attribute :default_api_resource_config_context unless respond_to?(:default_api_resource_config_context)
            if send("#{ctx}_api_resource_default")
              self.default_api_resource_config_context= "#{ctx}"
            end

            define_inheritable_singleton_method(:api_resource?) { true }

            include InstanceMethods
            propagate_deferred_api_resource_context(:api_resource, ctx)
          end

          def api_resource_of(ctx=nil)
            ctx ||= try(:default_api_resource_config_context) || "default"
            cfg = _api_resource_config_for(ctx)
            return cfg if cfg

            fallback = try(:default_api_resource_config_context)
            return if fallback.nil? || fallback.to_s == ctx.to_s

            _api_resource_config_for(fallback)
          end

          def _api_resource_config_for(ctx)
            cfg = respond_to?("#{ctx}_api_resource_config") ? send("#{ctx}_api_resource_config") : nil
            cfg.is_a?(::Plugins::Models::Concerns::Config) ? cfg : nil
          end
          private :_api_resource_config_for

          def api_resource?
            false
          end

          private

          def prepare_inherited_api_resource_config(kind:, context:, source:, options:, defaults:)
            source_cfg = send("_#{kind}_config_for", source)
            raise ArgumentError, "Unknown #{kind} context: #{source}" unless source_cfg

            inherited_cfg = source_cfg.dup
            if local_api_resource_context?(kind, context)
              current_cfg = send("_#{kind}_config_for", context)
              default_cfg = ::Plugins::Models::Concerns::Config.build(
                **::Plugins::Models::Concerns::ApiResource.deep_dup_options(defaults)
              )
              local_overrides = ::Plugins::Models::Concerns::ApiResource.prune_default_values(current_cfg, default_cfg)
              inherited_cfg = inherited_cfg.deep_merge(local_overrides)
              inherited_cfg.set(:default, current_cfg.values[:default]) unless options.key?(:default)
            else
              current_cfg = send("_#{kind}_config_for", context)
              inherited_cfg = compose_inherited_target_actions(inherited_cfg, current_cfg) if current_cfg
              inherited_cfg.set(:default, defaults[:default]) unless options.key?(:default)
            end

            inherited_cfg.set(:context, context)
            inherited_cfg.set_context(self)

            reader = "_#{context}_#{kind}_config"
            if respond_to?(reader)
              send("#{reader}=", inherited_cfg)
              defaults
            else
              defaults.merge(inherited_cfg.values)
            end
          end

          def compose_inherited_target_actions(source_config, target_config)
            %i[resource_actions collection_actions].each_with_object(source_config) do |key, config|
              source_actions = config.values[key]
              target_actions = target_config.values[key]
              next unless source_actions.is_a?(::Plugins::Models::Concerns::Config::Collection)
              next unless target_actions.is_a?(::Plugins::Models::Concerns::Config::Collection)

              config.add(key, source_actions.deep_merge(target_actions))
            end
          end

          def local_api_resource_context?(kind, context)
            !local_api_resource_override(kind, context).nil?
          end

          def record_local_api_resource_context(kind, context, baseline:, explicit_option_keys:, preserve_composed_source:)
            current_config = send("_#{kind}_config_for", context)
            comparison_config = if preserve_composed_source
                                  deferred_api_resource_default_config(kind)
                                else
                                  baseline
                                end
            local_override = ::Plugins::Models::Concerns::ApiResource.prune_default_values(
              current_config,
              comparison_config
            )
            explicit_option_keys.each do |key|
              local_override.add(
                key,
                ::Plugins::Models::Concerns::ApiResource.deep_dup_option_value(current_config.values[key])
              )
            end

            local_contexts = instance_variable_get(:@_plugins_local_api_resource_contexts) || {}
            previous_override = local_contexts.fetch(kind, {})[context.to_s]
            local_override = previous_override.deep_merge(local_override) if previous_override
            local_override.set_context(self)
            local_contexts[kind] = local_contexts.fetch(kind, {}).merge(context.to_s => local_override)
            instance_variable_set(:@_plugins_local_api_resource_contexts, local_contexts)
          end

          def local_api_resource_override(kind, context)
            local_contexts = instance_variable_get(:@_plugins_local_api_resource_contexts)
            local_contexts && local_contexts.fetch(kind, {})[context.to_s]
          end

          def deferred_api_resource_declaration_baseline(kind, context, setup_defaults)
            current_config = send("_#{kind}_config_for", context)
            return current_config.dup if current_config

            ::Plugins::Models::Concerns::Config.build(
              **::Plugins::Models::Concerns::ApiResource.deep_dup_options(setup_defaults)
            )
          end

          def deferred_api_resource_default_config(kind)
            defaults = if kind == :api_resource
                         ::Plugins::Models::Concerns::ApiResource.default_api_options
                       else
                         ::Plugins::Models::Concerns::ApiResource.default_options
                       end
            ::Plugins::Models::Concerns::Config.build(
              **::Plugins::Models::Concerns::ApiResource.deep_dup_options(defaults)
            )
          end

          def propagate_deferred_api_resource_context(kind, context)
            return unless respond_to?(:subclasses)

            config = send("_#{kind}_config_for", context)
            subclasses.each do |subclass|
              next unless subclass.respond_to?("#{kind}_of")

              subclass.send(:inherit_deferred_api_resource_context, kind, context, config)
            end
          end

          def inherit_deferred_api_resource_context(kind, context, parent_config)
            config = parent_config.dup
            local_override = local_api_resource_override(kind, context)
            config.deep_merge!(local_override) if local_override
            config.set_context(self)

            writer = "_#{context}_#{kind}_config="
            unless respond_to?(writer)
              inheritable_class_attribute "_#{context}_#{kind}_config".to_sym
            end
            send(writer, config)
            propagate_deferred_api_resource_context(kind, context)
          end

        end

        module InstanceMethods
          def grape_api_resource_of(ctx=nil)
            ctx ||= self.class.default_grape_api_resource_config_context
            cfg = _grape_api_resource_config_for(ctx)
            return cfg if cfg

            fallback = self.class.default_grape_api_resource_config_context
            return if fallback.nil? || fallback.to_s == ctx.to_s

            _grape_api_resource_config_for(fallback)
          end

          def _grape_api_resource_config_for(ctx)
            cfg = respond_to?("#{ctx}_grape_api_resource_config") ? send("#{ctx}_grape_api_resource_config") : nil
            cfg.is_a?(::Plugins::Models::Concerns::Config) ? cfg : nil
          end
          private :_grape_api_resource_config_for

          def api_resource_of(ctx=nil)
            ctx ||= self.class.default_api_resource_config_context
            cfg = _api_resource_config_for(ctx)
            return cfg if cfg

            fallback = self.class.default_api_resource_config_context
            return if fallback.nil? || fallback.to_s == ctx.to_s

            _api_resource_config_for(fallback)
          end

          def _api_resource_config_for(ctx)
            cfg = respond_to?("#{ctx}_api_resource_config") ? send("#{ctx}_api_resource_config") : nil
            cfg.is_a?(::Plugins::Models::Concerns::Config) ? cfg : nil
          end
          private :_api_resource_config_for
        end

      end
    end
  end
end
