module Plugins
  module Grape
    module Concerns
      module Authorize

        def self.included(base)
          base.inheritable_class_attribute :_skip_authorization
          # base.before do
          #   self.class.inheritable_class_attribute :_skip_authorization
          #   self.class._skip_authorization= base._skip_authorization
          # end
          base.extend ClassMethods
          base.helpers HelperMethods
          base.requires_authorization! if base.api_config.requires_authorization
        end

        module ClassMethods
          def requires_authorization!
            before do
              unless self.class_context._skip_authorization || skip_authorization?
                authorize_route!
              end
            end
          end
        end

        module HelperMethods

          attr_accessor :authorized_action

          def authorize_route!
            unauthorized! unless authorize
          end

          def authorize(__resources= :all)
            #opts = env['api.endpoint'].options[:route_options]
            opts = route.options
            return true unless opts.key?(:authorize)
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

          def skip_authorization?
            route_setting(:skip_authorization)
          end

        end

      end
    end
  end
end