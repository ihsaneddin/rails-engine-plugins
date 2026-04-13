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
            #opts = env['api.endpoint'].options[:route_options]
            # opts = route.options
            # return true unless opts.key?(:authorize)
            # if opts.key?(:authorize)
            #   authorization_opts= opts[:authorize].dup
            #   if authorization_opts.length == 2
            #     _resources_ = authorization_opts.last
            #     case _resources_
            #     when Symbol
            #       authorization_opts[1] = self.send(_resources_) if respond_to?(_resources_)
            #     when String
            #       if _resources_[0] == "@"
            #         authorization_opts[1] = instance_variable_get(_resources_)
            #       else
            #         authorization_opts[1] = self.send(_resources_) if respond_to?(_resources_)
            #       end
            #     when Proc
            #       authorization_opts[1] = instance_exec(&authorization_opts[1])
            #     end
            #     return if authorization_opts.last.nil?
            #   elsif authorization_opts.length == 1
            #     authorization_opts[1] = __resources
            #   end
            #   if authorization_opts[0].is_a?(Array)
            #     authorized = authorization_opts[0].any? {|act| authorize! act, authorization_opts[1], *authorization_opts[2..-1] }
            #     if authorized
            #       self.authorized_action = authorization_opts[0]
            #     end
            #     unless authorized
            #       raise Plugins::Errors::ApiAuthorizationError.new("Unauthorized", authorization_opts[0], authorization_opts[1], [])
            #     end
            #   else
            #     authorize!(*authorization_opts)
            #     self.authorized_action= authorization_opts[0]
            #   end
            # end
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
