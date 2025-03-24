module Plugins
  module Configuration
    module Core

      def self.included base
        base.mattr_accessor :events
        base.mattr_accessor :api
        base.mattr_accessor :grape_api
        base.mattr_accessor :permission_set_class
        base.mattr_accessor :permission_class
        base.events= Plugins::Configuration::Events.new(base.name.split("::")[0].underscore)
        base.api= Plugins::Configuration::Api
        base.grape_api= Plugins::Configuration::GrapeApi
        base.permission_set_class = Plugins::Configuration::Permissions::PermissionSet
        base.permission_class= Plugins::Configuration::Permissions::Permission

        base.mattr_accessor :bus
        base.bus = Plugins::Configuration::Bus
        base.extend ClassMethods
      end

      module ClassMethods
        def setup &block
          raise "Block is not provided" unless block_given?
          block.arity.zero? ? instance_eval(&block) : yield(self)
        end

        def configure_events &block
          events.configure(&block)
        end

        def api &block
          if block_given?
            api.setup(&block)
          else
            super
          end
        end

        def grape_api &block
          if block_given?
            grape_api.setup(&block)
          else
            super
          end
        end

        def bus &block
          if block_given?
            bus.setup(&block)
          else
            super
          end
        end

        def draw_permissions &block
          permission_set_class.permission_class= self.permission_class
          permission_set_class.draw_permissions(&block)
        end
      end

    end
  end
end