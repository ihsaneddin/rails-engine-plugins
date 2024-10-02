module Plugins
  module Grape
    module Concerns
      module Authorize

        def self.included(base)
          base.helpers HelperMethods
          # unless base.respond_to?(:defined_permissions)
          #   base.class_attribute :defined_permissions
          # end
          # base.helpers do
          #   def define_permissions(permissions)
          #     @defined_permissions = permissions
          #   end

          #   def defined_permissions
          #     @defined_permissions
          #   end

          #   def get_defined_permissions
          #     _permissions = case defined_permissions
          #       when Proc
          #         instance_exec(_permissions)
          #       else
          #         _permissions
          #       end
          #     return if _permissions.nil?
          #     if _permissions.is_?(Plugins::Configuration::Permissions::PermissionSet)
          #       raise "Invalid permissions"
          #     end
          #     _permissions
          #   end
          # end
          # permissions = base.defined_permissions
          # base.before do
          #   define_permissions(defined_permissions)
          # end
          # base.after_validation do
          #   authorize_route!
          # end
        end

        module HelperMethods

          attr_accessor :authorized_action

          def authorize_route!
            unless skip_authorization!
              unauthorized! unless authorize
            end
          end

          def authorize(__resources= :all)
            #opts = env['api.endpoint'].options[:route_options]
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
                when Proc
                  authorization_opts[1] = instance_exec(&authorization_opts[1])
                end
                return if authorization_opts.last.nil?
              elsif authorization_opts.length == 1
                authorization_opts[1] = __resources
              end
              if authorization_opts[0].is_a?(Array)
                authorized = authorization_opts[0].any? {|act| authorize! act, authorization_opts[1], *authorization_opts[2..-1] }
                if authorized
                  self.authorized_action = authorization_opts[0]
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

          def authorize!(*args)
            # if _permissions = get_defined_permissions
            #   _permissions.authorize(*args)
            # else
            #   true
            # end
            raise "Must be implemented"
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