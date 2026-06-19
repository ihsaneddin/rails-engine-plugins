module Plugins
  module Controllers
    module Concerns
      module Authorize

        def self.included(base)
          base.include InstanceMethods
          base.extend ClassMethods
          base.requires_authorization! if base.api_config.requires_authorization
        end

        module InstanceMethods

          def authorize_route!
            unless skip_authorization
              unauthorized! unless authorize
            end
          end

          def authorize(*args)#= :all)
            if api_config.authorize.is_a?(Proc)
              instance_exec(*args, &self.api_config.authorize)
            else
              api_config.authorize
            end
          end

          def authorize!(*args)
            # if _permissions = get_defined_permissions
            #   _permissions.authorize(*args)
            # else
            #   true
            # end
            authorize(*args) || raise(Plugins::Errors::AuthorizationError)
          end

          def unauthorized!
            raise Plugins::Errors::AuthorizationError
          end

          def skip_authorization
            @skip_authorization
          end

          def skip_authorization!
            @skip_authorization= true
          end

        end

        module ClassMethods
          def requires_authorization!
            prepend_before_action do
              authorize_route!
            end
          end

          def skip_authorization!
            prepend_before_action do
              skip_authorization!
            end
          end
        end

      end
    end
  end
end
