module Plugins
  module Routes
    module Helpers
      def resourceful_routes(resource,
                             controller: nil,
                             only: nil,
                             except: nil,
                             path: nil,
                             path_names: nil,
                             as: nil,
                             param: nil,
                             constraints: nil,
                             defaults: nil,
                             shallow: nil,
                             collection_action_path: "action/:collection_action",
                             resource_action_path: "action/:resource_action",
                             collection_action_via: [:get, :post, :put, :delete],
                             resource_action_via: [:get, :post, :put, :delete])
        controller ||= resource
        resources_options = {
          controller: controller,
          only: only,
          except: except,
          path: path,
          path_names: path_names,
          as: as,
          param: param,
          constraints: constraints,
          defaults: defaults,
          shallow: shallow
        }.compact

        resources resource, **resources_options do
          if collection_action_path
            match collection_action_path,
                  to: "#{controller}#collection_action",
                  via: (collection_action_via || [:get, :post, :put, :delete]),
                  on: :collection
          end
          if resource_action_path
            match resource_action_path,
                  to: "#{controller}#resource_action",
                  via: (resource_action_via || [:get, :post, :put, :delete]),
                  on: :member
          end
        end
      end
    end
  end
end
