module Plugins
  module Grape
    module Concerns
      module Authorize

        def self.included(base)
          base.helpers HelperMethods
          base.helpers do
            def define_permissions(permissions)
              @permissions = permissions
            end
          end
          base.after_validation do
            authorize_route!
          end
        end

        module HelperMethods

          attr_accessor :authorized_action

          def authorize_route!
            unless skip_authorization!
              unauthorized! unless authorize
            end
          end

          def authorize(__resources= nil)
            opts = route.options
            if opts.key?(:authorize)
              authorization_opts= opts[:authorize].dup
              if authorization_opts.length == 2
                _resources_ = authorization_opts.last
                case _resources_
                when Symbol
                  authorization_opts[1] = self.send(_resources_) if respond_to?(_resources_)
                when String
                  if _resources_[0] == "@"
                    authorization_opts[1] = instance_variable_get(_resources_)
                  else
                    authorization_opts[1] = self.send(_resources_) if respond_to?(_resources_)
                  end
                end
                return if authorization_opts.last.nil?
              elsif authorization_opts.length == 1
                authorization_opts[1] = __resources
              end
              if authorization_opts[0].is_a?(Array)
                authorized = false
                authorization_opts[0].each do |act|
                  authorized = authorize! act, authorization_opts[1]
                  if authorized
                    self.authorized_action = act
                    break
                  end
                end
                unless authorized
                  raise Plugins::Errors::ApiAuthorizationError.new("Unauthorized", authorization_opts[0], authorization_opts[1], [])
                end
              else
                authorize!(*authorization_opts)
                self.authorized_action= authorization_opts[0]
              end
            end
          end

          def authorize!

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