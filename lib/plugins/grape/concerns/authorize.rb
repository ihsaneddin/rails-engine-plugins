module Plugins
  module Grape
    module Concerns
      module Authorize

        def self.included(base)
          base.helpers HelperMethods
          base.before do
            authorize!
          end
        end

        module HelperMethods

          def authorize!
            unless skip_authorization!
              unauthorized! unless authorize_user!
            end
          end

          def authorize_user!
            #TODO
          end

          def unauthorized!
            raise Plugins::Errors::ApiAuthorizationError
          end

          def skip_authorization!
            route_setting(:skip_authorization)
          end

        end

      end
    end
  end
end