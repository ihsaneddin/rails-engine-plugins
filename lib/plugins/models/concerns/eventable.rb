require 'set'

module Plugins
  module Models
    module Concerns
      module Eventable

        extend ActiveSupport::Concern

        module PublishesEvents

          mattr_accessor :eventable_publishes_events_classes
          @@eventable_publishes_events_classes = []

          def self.<<(base)
            @@eventable_publishes_events_classes << base
          end

          def self.eventable_register_events
            @@eventable_publishes_events_classes.each(&:eventable_register_events!)
          end

          def self.included(base)
            return if base.instance_variable_defined?(:@_eventable_loaded)
            base.include Plugins.decorators.inheritables.singleton_methods
            base.include Plugins::Decorators.method_decorators
            base.inheritable_class_attribute :eventable_events
            base.inheritable_class_attribute :eventable_bus_name
            base.eventable_events ||= {}
            base.eventable_bus_name = :default
            base.define_inheritable_singleton_method :eventable_bus do
              Plugins::Configuration::Bus
            end
            base.define_method :eventable_bus do
              self.class.eventable_bus
            end

            self << base

            base.define_method_decorator :eventable_publish_event_decorator do |method_name, original, *args, block, **opts|
              result = original.call(*args, &block)
              skip_if = opts[:skip_if]
              if skip_if.is_a?(Proc)
                skip_if = instance_exec(&skip_if)
              end
              unless skip_if
                payload = opts[:payload]
                if payload.is_a?(Proc)
                  payload = instance_exec(&payload)
                end
                payload ||= { object: self }
                self.class.eventable_publish_event_for_method(method_name, **(payload.is_a?(Hash) ? payload : {object: payload}))
              end
              result
            end

            base.extend ClassMethods
            base.instance_variable_set(:@_eventable_loaded, true)
          end

          module ClassMethods
            def publishes_event(event_name, on:, bus: nil, prefix: nil, payload: nil, skip_if: false, &block)
              method_key = on&.to_sym
              prefix ||= name.demodulize.underscore
              bus ||= eventable_bus_name || :default
              payload ||= block

              self.eventable_events = eventable_events.deep_dup
              self.eventable_events[method_key] ||= []

              self.eventable_events[method_key] << {
                event_name: event_name.to_sym,
                bus: bus.to_sym,
                prefixes: [prefix],
              }
              decorate_method( on, with: :eventable_publish_event_decorator, **{ payload: payload, skip_if: skip_if })
            end

            def eventable_publish_event_for_method(method_name, **payload)
              events = self.eventable_events[method_name.to_sym] || []
              events.each do |eb|
                eb[:prefixes].each do |prefix|
                  eventable_bus.instance(eb[:bus], init: true)
                  eventable_bus.publish(eb[:bus], [prefix, eb[:event_name]].join("."), **payload)
                end
              end
            end

            def eventable_register_events!
              eventable_events.each_value do |events|
                events.each do |eb|
                  eb[:prefixes].each do |prefix|
                    eventable_bus.instance(eb[:bus], init: true)
                    eventable_bus.register(eb[:bus], [prefix, eb[:event_name]].join("."))
                  end
                end
              end
            end

            def inherited(subclass)
              super(subclass)
              subclass_prefix = subclass.name.demodulize.underscore
              if subclass.eventable_events
                subclass.eventable_events.each do |_method, events|
                  events.each do |event|
                    event[:prefixes] ||= []
                    unless event[:prefixes].include?(subclass_prefix)
                      event[:prefixes] << subclass_prefix
                    end
                  end
                end
              end
            end
          end

          def publish_event(event_name, bus: nil, prefix: nil, **payload)
            prefix ||= self.class.name.demodulize.underscore
            bus ||= self.class.eventable_bus_name || :default

            eventable_bus.instance(bus.to_sym, init: true)
            eventable_bus.publish(bus.to_sym, [prefix, event_name].map(&:to_s).compact.join("."), **payload)
          end

        end

        module SubscribesToEvents

          mattr_accessor :eventable_subsciber_classes
          @@eventable_subsciber_classes = []

          def self.<<(base)
            @@eventable_subsciber_classes << base
          end

          def self.eventable_register_event_buses!
            @@eventable_subsciber_classes.each(&:register_event_subscriptions!)
          end

          def self.included(base)
            base.include(self.[])
          end

          def self.[](**options)
            Class.new(Module) do
              define_method(:included) do |base|
                base.include(::Omnes::Subscriber[**options])
                base.include Plugins.decorators.inheritables.singleton_methods
                base.inheritable_class_attribute :eventable_subscription_buses
                base.eventable_subscription_buses = []
                base.extend(ClassMethods)
                base.define_inheritable_singleton_method :eventable_bus do
                  Plugins::Configuration::Bus
                end
                base.define_method :eventable_bus do
                  self.class.eventable_bus
                end
                ::Plugins::Models::Concerns::Eventable::SubscribesToEvents << base
              end
            end.new
          end

          module ClassMethods

            def on_event(*args, &block)
              opts = args.extract_options!
              events = args
              bus = opts[:bus] || :default
              handler = opts[:handler] || block
              case handler
              when Proc
                events.each do |event_name|
                  eventable_bus.subscribe(bus.to_sym, event_name, &handler)
                end
              when String,Symbol
                events.each do |event_name|
                  handle event_name, with: handler.to_sym
                end
                eventable_subscription_buses << bus
              else
                events.each do |event_name|
                  eventable_bus.subscribe(bus.to_sym, event_name, handler)
                end
              end
            end

            def on_matched_event(matcher, **opts, &block)
              handler = opts[:handler] || block
              bus = opts[:bus] || :default
              case handler
              when Proc
                eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, &handler)
              when String,Symbol
                handle_with_matcher matcher, with: handler.to_sym
                eventable_subscription_buses << bus
              else
                eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, handler)
              end
            end

            def on_all_events **opts, &block
              handler = opts[:handler] || block
              bus = opts[:bus] || :default
              matcher = opts[:matcher]
              case handler
              when Proc
                eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, &handler)
              when String,Symbol
                handle_with_matcher matcher, with: handler.to_sym
                eventable_subscription_buses << bus
              else
                eventable_bus.subscribe_to_all(bus.to_sym, matcher, handler)
              end
            end

            def eventable_register_event_buses!
              eventable_subscription_buses.each do |bus|
                bus_obj = eventable_bus.instance(bus, init: true)
                new.subscribe_to(bus_obj)
              end
            end
          end
        end

      end
    end
  end
end