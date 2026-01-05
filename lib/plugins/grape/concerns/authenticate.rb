module Plugins
  module Grape
    module Concerns
      module Authenticate

        def self.included(base)
          base.inheritable_class_attribute :_skip_authentication
          # base.before do
          #   self.class.inheritable_class_attribute :_skip_authentication
          #   self.class._skip_authentication= base._skip_authentication
          # end
          base.extend ClassMethods
          base.helpers HelperMethods
          base.requires_authentication! if base.api_config.requires_authentication
        end

        module ClassMethods
          def requires_authentication!
            before do
              unless self.class_context._skip_authentication || skip_authentication?
                authenticate!
              end
            end
          end

          def skip_authentication!
            route_setting :skip_authentication, true
          end

        end

        module HelperMethods

          def authenticate!
            current_user ? current_user : reject_unauthenticated!
          end

          def current_user
            @current_user ||= instance_exec(&api_config.authenticate) if api_config.authenticate.is_a?(Proc)
          end

          def reject_unauthenticated!
            raise Plugins::Errors::ApiAuthenticationError unless @current_user
          end

          def skip_authentication?
            route_setting(:skip_authentication)
          end

        end

      end
    end
  end
end