module Plugins
  module Configuration
    module Bus
      @@registered_buses = {}
      @@blocks = []

      def self.setup(&block)
        @@blocks << block if block_given?
      end

      def self.apply_setup!
        @@blocks.each { |block| instance_exec(&block) }
      end

      def self.create(name)
        @@registered_buses[name.to_sym] = Omnes::Bus.new
      end

      def self.instance(name, init: false, &block)
        name = name.to_sym
        @@registered_buses[name] ||= create(name) if init
        if block_given?
          block.arity.zero? ? instance_eval(&block) : yield(self)
        else
          @@registered_buses[name]
        end
      end

      def self.with_instance(name)
        yield(instance(name)) if block_given? && instance(name)
      end

      def self.register(name, event)
        with_instance(name) { |bus| bus.register(event) }
      end

      def self.publish(name, event, **opts)
        with_instance(name) { |bus| bus.publish(event, **opts) }
      end

      def self.subscribe(name, event, handler = nil, &block)
        if block_given?
          with_instance(name) { |bus| bus.subscribe(event, &block) }
        else
          with_instance(name) { |bus| bus.subscribe(event, handler) }
        end
      end

      def self.subscribe_to_all(name, handler= nil, &block)
        if block_given?
          with_instance(name) { |bus| bus.subscribe_to_all(&block) }
        else
          with_instance(name) { |bus| bus.subscribe_to_all(handler) }
        end
      end

      def self.subscribe_with_matcher(name, matcher, handler=nil, &block)
        if matcher && !matcher.is_a?(Proc)
          raise ArgumentError "matcher have to be a Proc"
        end
        if block_given?
          with_instance(name) { |bus| bus.subscribe_with_matcher(matcher, &block) }
        else
          with_instance(name) { |bus| bus.subscribe_with_matcher(matcher, handler) }
        end
      end

      def self.unsubscribe(name, event)
        with_instance(name) { |bus| bus.unsubscribe(event) }
      end

      def self.clear(name)
        with_instance(name) { |bus| bus.clear }
      end

      def self.clear_all
        @@registered_buses.each_key { |name| clear(name) }
      end
    end
  end
end

# module Plugins
#   module Configuration
#     module Bus

#       @@registered_buses = {}
#       @@blocks = []

#       def self.setup &block
#         if block_given?
#           #block.arity.zero? ? instance_eval(&block) : yield(self)
#           @@blocks << block
#         end
#       end

#       def self.setup &block
#         if block_given?
#           #block.arity.zero? ? instance_eval(&block) : yield(self)
#           @@blocks << block
#         end
#       end

#       def self.apply_setup!
#         @@blocks.each do |block|
#           instance_exec(&block)
#         end
#         #self.clear_all
#       end

#       def self.create(name)
#         @@registered_buses[name]= Omnes::Bus.new
#       end

#       def self.instance(name, init: false)
#         _instance = self.registered_buses[name]
#         if _instance.blank? && init
#           _instance = self.create(name)
#         end
#         _instance
#       end

#       def self.with_instance name, &block
#         _instance = self.registered_buses[name]
#         if _instance.blank?
#           yield _instance
#         end
#       end

#       def self.register(name, event)
#         with_instance(name) do |instance|
#           instance.register(event)
#         end
#       end

#       def self.publish(name, event, **opts)
#         with_instance(name) do |instance|
#           instance.publish(event, **opts)
#         end
#       end

#       def self.subscribe(name, event, &block)
#         if block_given?
#           with_instance(name) do |instance|
#             instance.subscribe(event, &block)
#           end
#         end
#       end

#       def self.subscriptions(name)
#         with_instance(name) do |instance|
#           instance.subscriptions
#         end
#       end

#       def self.unsubscribe(name, event)
#         with_instance(name) do |instance|
#           instance.unsubscribe(event)
#         end
#       end

#       def self.clear(name)
#         with_instance(name) do |instance|
#           instance.clear
#         end
#       end

#       def self.clear_all()
#         @@registered_buses.each do |k|
#           with_instance(k) do |instance|
#             instance.clear
#           end
#         end
#       end

#     end

#   end
# end