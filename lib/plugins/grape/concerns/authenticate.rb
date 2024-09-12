module Plugins
  module Grape
    module Concerns
      module Authenticate

        def self.included(base)
          base.helpers HelperMethods
          base.before do
            authenticate!
          end
        end

        module HelperMethods

          def authenticate!
            unless skip_authentication!
              api_current_user ? api_current_user : reject_unauthenticated!
            end
          end

          def api_current_user
            @api_current_user ||= instance_exec(&Plugins.config.grape_api.authenticate)
          end

          def reject_unauthenticated!
            raise Plugins::Errors::ApiAuthenticationError unless api_current_user
          end

          def skip_authentication!
            route_setting(:skip_authentication)
          end

        end

      end
    end
  end
end