module Plugins
  module Models
    module Concerns
      module ApiResource

        def self.included base
          extend ClassMethods
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
            resource_finder: proc { |api, query, identifier| query.find_by!(identifier) },
            resources_finder: proc { |api, query, identifier|  query.where(identifier) },
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

          def api_resource *args, &block

            ctx = args[0] || "default"
            opts = args.extract_options!

            opts[:context] = ctx

            default_opts = ::Plugins::Models::Concerns::ApiResource.default_options
            ::Plugins::Models::Concerns::Config.setup(self, "#{ctx}_grape_api_resource_config", opts, default_opts,
                                                        method_prefix: "#{ctx}_grape_api_resource", &block)


          end

          def api_resource_of(ctx="default")
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