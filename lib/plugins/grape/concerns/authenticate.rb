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
              current_user ? current_user : reject_unauthenticated!
            end
          end

          def current_user
            @current_user ||= instance_exec(&grape_api_config.authenticate)
          end

          def reject_unauthenticated!
            raise Plugins::Errors::ApiAuthenticationError unless current_user
          end

          def skip_authentication!
            route_setting(:skip_authentication)
          end

        end

      end
    end
  end
end