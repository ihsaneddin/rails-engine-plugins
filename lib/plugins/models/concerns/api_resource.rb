module Plugins
  module Models
    module Concerns
      module ApiResource

        def self.included base
          base.extend ClassMethods
        end

        def self.plugins_config
          ::Plugins::Models::Concerns::Config
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
            default: false,
            resource_finder: proc { |query, identifier, api| query.find_by!(identifier) },
            resources_finder: proc { |query, identifier, api|  query.where(identifier) },
            resource_identifier: "id",
            resource_finder_key: "id",
            resource_params_attributes: [],
            query_scope: proc {|query| query },
            after_fetch_resource: nil,
            should_paginate: true,
            presenter: nil,
          }

        end

        module ClassMethods

          def grape_api_resource *args, &block

            ctx = args[0] || "default"
            opts = args.extract_options!

            opts[:context] = ctx

            default_opts = ::Plugins::Models::Concerns::ApiResource.default_options
            ::Plugins::Models::Concerns::Config.setup(self, "#{ctx}_grape_api_resource_config", opts, default_opts,
                                                        method_prefix: "#{ctx}_grape_api_resource", &block)

            inheritable_class_attribute :default_grape_api_resource_config_context unless respond_to?(:default_grape_api_resource_config_context)
            if send("#{ctx}_grape_api_resource_default")
              self.default_grape_api_resource_config_context= "#{ctx}"
            end

            define_inheritable_singleton_method(:grape_api_resource?) { true }

            include InstanceMethods
          end

          def grape_api_resource_of(ctx=nil)
            if ctx.nil?
              ctx = self.default_grape_api_resource_config_context
            end
            cfg = respond_to?("#{ctx}_grape_api_resource_config") ? send("#{ctx}_grape_api_resource_config") : nil
            if cfg && cfg.is_a?(::Plugins::Models::Concerns::Config)
              return cfg
            end
          end

        end

        module InstanceMethods
          def grape_api_resource_of(ctx=nil)
            if ctx.nil?
              ctx = self.class.default_grape_api_resource_config_context
            end
            cfg = send("#{ctx}_grape_api_resource_config")
            if cfg && cfg.is_a?(::Plugins::Models::Concerns::Config)
              return cfg
            end
          end
        end

      end
    end
  end
end