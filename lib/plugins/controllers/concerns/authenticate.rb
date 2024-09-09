module Plugins
  module Controllers
    module Concerns
      module Authenticate

        extend ActiveSupport::Concern

        included do
          attr_accessor :skip_authentication
          prepend_before_action :authenticate!, unless: :skip_authentication
        end

        def authenticate!
          api_current_user ? api_current_user : reject_unauthenticated!
        end

        def api_current_user
          @api_current_user ||= instance_exec(&Plugins.config.api.authenticate)
        end

        def reject_unauthenticated!
          raise Plugins::Errors::ApiAuthenticationError unless api_current_user
        end

        def skip_authentication!
          self.skip_authentication= true
        end

      end
    end
  end
end
