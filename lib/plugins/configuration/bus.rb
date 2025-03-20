module Plugins
  module Configuration

    module Bus

      @@registered_buses = {}
      @@blocks = []

      def self.setup &block
        if block_given?
          #block.arity.zero? ? instance_eval(&block) : yield(self)
          @@blocks << block
        end
      end

      def self.apply_setup!
        @@blocks.each do |block|
          block.arity.zero? ? instance_eval(&block) : yield(self)
        end
        self.clear_all
      end

      def self.create(name)
        @@registered_buses[name]= Omnes::Bus.new
      end

      def self.instance(name, init: false)
        _instance = self.registered_buses[name]
        if _instance.blank? && init
          _instance = self.create(name)
        end
        _instance
      end

      def self.with_instance name, &block
        _instance = self.registered_buses[name]
        if _instance.blank?
          yield _instance
        end
      end

      def self.register(name, event)
        with_instance(name) do |instance|
          instance.register(event)
        end
      end

      def self.publish(name, event, **opts)
        with_instance(name) do |instance|
          instance.publish(event, **opts)
        end
      end

      def self.subscribe(name, event, &block)
        if block_given?
          with_instance(name) do |instance|
            instance.subscribe(event, &block)
          end
        end
      end

      def self.subscriptions(name)
        with_instance(name) do |instance|
          instance.subscriptions
        end
      end

      def self.unsubscribe(name, event)
        with_instance(name) do |instance|
          instance.unsubscribe(event)
        end
      end

      def self.clear(name)
        with_instance(name) do |instance|
          instance.clear
        end
      end

      def self.clear_all()
        @@registered_buses.each do |k|
          with_instance(k) do |instance|
            instance.clear
          end
        end
      end

    end

  end
end