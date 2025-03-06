module Plugins
  module Controllers
    module Concerns
      module Authenticate

        # extend ActiveSupport::Concern

        # included do
        #   attr_accessor :skip_authentication
        #   prepend_before_action :authenticate!, unless: :skip_authentication
        # end

        # def authenticate!
        #   api_current_user ? api_current_user : reject_unauthenticated!
        # end

        # def api_current_user
        #   @api_current_user ||= instance_exec(&Plugins.config.api.authenticate)
        # end

        # def reject_unauthenticated!
        #   raise Plugins::Errors::ApiAuthenticationError unless api_current_user
        # end

        # def skip_authentication!
        #   self.skip_authentication= true
        # end

        def self.included(base)
          base.include InstanceMethods
          base.extend ClassMethods
          base.authenticate!
        end

        module InstanceMethods

          def authenticate!
            unless skip_authentication
              current_user ? current_user : reject_unauthenticated!
            end
          end

          def current_user
            @current_user ||= instance_exec(&api_config.authenticate) if api_config.authenticate.is_a?(Proc)
          end

          def reject_unauthenticated!
            raise Plugins::Errors::ApiAuthenticationError unless @current_user
          end

          def skip_authentication
            @skip_authentication
          end

          def skip_authentication!
            @skip_authentication= true
          end

        end

        module ClassMethods

          def authenticate!
            prepend_before_action do
              authenticate!
            end
          end

          def skip_authentication *args
            prepend_before_action :skip_authentication!, *args
          end

        end

      end
    end
  end
end
