require 'set'

module Plugins
  module Models
    module Concerns
      module Eventable
        extend ActiveSupport::Concern

        included do
          class_attribute :_instrumented_callbacks
          self._instrumented_callbacks = {}

          [
            :before_validation, :after_validation,
            :before_save, :after_save,
            :before_create, :after_create,
            :before_update, :after_update,
            :before_destroy, :after_destroy
          ].each do |kallback|
            class_eval <<-CODE, __FILE__, __LINE__ + 1
              def _callback_event_#{kallback}
                if self.class.respond_to?(:events_config)
                  unless (self.class.instrumented_callbacks || []).include?('#{kallback}')
                    self.class.events_config.instrument(
                      type: self.class.event_base_name.demodulize.underscore.downcase + '.#{kallback}',
                      payload: self
                    )
                    self.class.instrumented_callbacks = '#{kallback}'
                  end
                end
              end
            CODE

            send kallback, "_callback_event_#{kallback}".to_sym
          end
        end

        class_methods do
          def instrumented_callbacks
            self._instrumented_callbacks[self.name] ||= []
          end

          def instrumented_callbacks=(v)
            self._instrumented_callbacks[self.name] ||= []
            self._instrumented_callbacks[self.name] << v
          end

          def event_base_name
            self.name
          end
        end

        module PublishesEvents
          mattr_accessor :eventable_publishes_events_classes
          @@eventable_publishes_events_classes = []

          mattr_accessor :registered
          @@registered = Set.new

          def self.<<(base)
            @@eventable_publishes_events_classes << base unless @@eventable_publishes_events_classes.include?(base)
          end

          def self.eventable_register_events
            @@eventable_publishes_events_classes.each do |klass|
              klass.eventable_register_events!
              klass.descendants.each(&:eventable_register_events!)
            end
          end

          def self.included(base)
            return if base.instance_variable_defined?(:@_eventable_loaded)

            base.include Plugins.decorators.inheritables.singleton_methods
            base.include Plugins::Decorators.method_decorators
            base.include Plugins::Decorators.hooks
            base.inheritable_class_attribute :eventable_events
            base.inheritable_class_attribute :eventable_bus_name

            base.eventable_events ||= {}
            base.eventable_bus_name = base.name.demodulize.underscore.to_sym

            base.define_inheritable_singleton_method :eventable_bus do
              Plugins::Configuration::Bus
            end

            base.define_method :eventable_bus do
              self.class.eventable_bus
            end

            self << base

            base.after_class_defined(base) do
              base.eventable_register_events!
            end

            base.define_method_decorator :eventable_publish_event_decorator do |method_name, original, *args, block, **opts|
              result = original.call(*args, &block)

              if result
                skip_if = opts[:skip_if]
                skip_if = instance_exec(&skip_if) if skip_if.is_a?(Proc)

                unless skip_if
                  payload = opts[:payload]
                  payload = instance_exec(&payload) if payload.is_a?(Proc)
                  payload ||= { object: self }

                  self.class.eventable_publish_event_for_method(
                    method_name,
                    **(payload.is_a?(Hash) ? payload : { object: payload })
                  )
                end
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
                prefixes: [prefix]
              }

              decorate_method(on, with: :eventable_publish_event_decorator, **{ payload: payload, skip_if: skip_if })
            end

            def register_events(*args)
              opts = args.extract_options!
              events = args
              bus_name = opts[:bus] || eventable_bus_name
              prefix = opts[:prefix] || name.demodulize.underscore

              events.each do |event_name|
                eventable_bus.instance(bus_name.to_sym, init: true)
                eventable_bus.register(bus_name.to_sym, [prefix, event_name].reject(&:blank?).join("_").to_sym)
              end
            end

            def eventable_publish_event_for_method(method_name, **payload)
              events = self.eventable_events[method_name.to_sym] || []
              events.each do |eb|
                eb[:prefixes].each do |prefix|
                  eventable_bus.instance(eb[:bus], init: true)
                  eventable_bus.publish(eb[:bus], [prefix, eb[:event_name]].reject(&:blank?).join("_").to_sym, **payload)
                end
              end
            end

            def eventable_register_events!
              unless eventable_registered?
                ::Plugins::Models::Concerns::Eventable::PublishesEvents.registered << self
                self.eventable_events.each_value do |events|
                  events.each do |eb|
                    eb[:prefixes].each do |prefix|
                      eventable_bus.instance(eb[:bus], init: true)
                      event = [prefix, eb[:event_name]].reject(&:blank?).join("_").to_sym
                      unless eventable_bus.registered?(eb[:bus], event)
                        eventable_bus.register(eb[:bus], event)
                      end
                    end
                  end
                end
              end
            end

            def eventable_registered?
              ::Plugins::Models::Concerns::Eventable::PublishesEvents.registered.any?{|klass| klass.name == self.name }
            end

            def inherited(subclass)
              super(subclass)
              return unless subclass.name
              subclass_prefix = subclass.name.demodulize.underscore
              if subclass.eventable_events
                subclass.eventable_events.each do |_method, events|
                  events.each do |event|
                    event[:prefixes] ||= []
                    event[:prefixes] << subclass_prefix unless event[:prefixes].include?(subclass_prefix)
                  end
                end
              end
              after_class_defined(subclass) do
                subclass.eventable_register_events!
              end
            end
          end

          def publish_event(event_name, bus: nil, prefix: nil, **payload)
            prefix ||= self.class.name.demodulize.underscore
            bus ||= self.class.eventable_bus_name || :default
            event_name = [prefix, event_name].map(&:to_s).compact.reject(&:blank?).join("_").to_sym
            if payload.blank?
              payload[:object]= self
            end
            eventable_bus.instance(bus.to_sym, init: true)
            eventable_bus.register(bus.to_sym, event_name) unless eventable_bus.registered?(bus.to_sym, event_name)
            eventable_bus.publish(bus.to_sym, event_name, **payload)
          end
        end

        module SubscribesToEvents
          mattr_accessor :eventable_subsciber_classes
          @@eventable_subsciber_classes = []
          @eventable_unload_callbacks = {}

          class SubscriptionRegistration
            attr_reader :bus, :subscriptions

            def initialize(bus)
              @bus = bus
              @subscriptions = []
            end

            def registry
              bus.registry
            end

            def subscribe(*args, **kwargs, &block)
              bus.subscribe(*args, **kwargs, &block).tap { |subscription| subscriptions << subscription }
            end

            def subscribe_to_all(*args, **kwargs, &block)
              bus.subscribe_to_all(*args, **kwargs, &block).tap { |subscription| subscriptions << subscription }
            end

            def subscribe_with_matcher(*args, **kwargs, &block)
              bus.subscribe_with_matcher(*args, **kwargs, &block).tap { |subscription| subscriptions << subscription }
            end

            def unsubscribe_all!
              subscriptions.each { |subscription| bus.unsubscribe(subscription) }
            end
          end

          def self.<<(base)
            @@eventable_subsciber_classes << base
          end

          def self.register_unload_callback(klass)
            return unless klass.name && defined?(Rails) && Rails.respond_to?(:application)
            return unless (application = Rails.application)

            loader = application.autoloaders.main
            return unless loader&.respond_to?(:on_unload)

            registered = (@eventable_unload_callbacks[loader] ||= Set.new)
            return if registered.include?(klass.name)

            loader.on_unload(klass.name) do |unloaded, _path|
              unloaded.eventable_unregister_event_buses!
              eventable_subsciber_classes.delete(unloaded)
            end
            registered.add(klass.name)
          end

          def self.eventable_register_event_buses!
            @@eventable_subsciber_classes.each do |klass|
              klass.eventable_register_event_buses!
              klass.descendants.each(&:eventable_register_event_buses!)
            end
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
                base.inheritable_class_attribute :eventable_subscription_definitions
                base.inheritable_class_attribute :eventable_event_object_classes
                base.eventable_subscription_buses = []
                base.eventable_subscription_definitions = []
                base.eventable_event_object_classes = nil
                base.extend(ClassMethods)
                base.include(InstanceMethods)

                base.define_inheritable_singleton_method :eventable_bus do
                  Plugins::Configuration::Bus
                end

                base.define_method :eventable_bus do
                  self.class.eventable_bus
                end

                base.attr_reader :id

                ::Plugins::Models::Concerns::Eventable::SubscribesToEvents << base

                tracer = TracePoint.new(:end) do |tp|
                  if tp.self == base
                    begin
                      base.eventable_register_event_buses!
                    rescue StandardError
                      ::Plugins::Models::Concerns::Eventable::SubscribesToEvents.eventable_subsciber_classes.delete(base)
                      raise
                    ensure
                      tracer.disable
                    end
                  end
                end

                tracer.enable
              end
            end.new
          end

          module ClassMethods
            def event_object_is_a(*klasses)
              self.eventable_event_object_classes = klasses.flatten.compact.presence
            end

            def on_event(*args, &block)
              opts = args.extract_options!
              events = args
              bus = opts[:bus] || :default
              handler = opts[:handler] || block

              eventable_bus.instance(bus.to_sym, init: true)
              adapter = eventable_handler_adapter(handler)
              events.each do |event_name|
                eventable_bus.register(bus.to_sym, event_name) unless eventable_bus.registered?(bus.to_sym, event_name)
                eventable_declare_subscription(bus, :event, adapter, event_name: event_name)
              end
            end

            def on_matched_event(matcher, **opts, &block)
              handler = opts[:handler] || block
              bus = opts[:bus] || :default

              eventable_declare_subscription(bus, :matcher, eventable_handler_adapter(handler), matcher: matcher)
            end

            def on_all_events(**opts, &block)
              handler = opts[:handler] || block
              bus = opts[:bus] || :default
              matcher = opts[:matcher]

              eventable_declare_subscription(
                bus, matcher ? :matcher : :all, eventable_handler_adapter(handler), matcher: matcher
              )
            end

            def eventable_declare_subscription(bus, kind, adapter, **options)
              bus = bus.to_sym
              self.eventable_subscription_definitions = eventable_subscription_definitions + [
                { bus: bus, kind: kind, adapter: adapter, **options }
              ]
              self.eventable_subscription_buses = (eventable_subscription_buses + [bus]).uniq
            end

            def eventable_handler_adapter(handler)
              case handler
              when Proc
                eventable_guarded_proc_handler(handler)
              when String, Symbol
                eventable_guarded_handler_method_name(handler)
              else
                eventable_guarded_callable_handler(handler)
              end
            end

            def eventable_guarded_handler_method_name(handler)
              handler_method_name = :"_eventable_guarded_#{handler}"
              original_handler = handler.to_sym

              return handler_method_name if instance_methods(false).include?(handler_method_name)

              define_method(handler_method_name) do |event|
                return unless eventable_event_object_matches?(event)

                public_send(original_handler, event)
              end

              handler_method_name
            end

            def eventable_guarded_proc_handler(handler)
              proc do |subscriber, event|
                next unless subscriber.eventable_event_object_matches?(event)

                subscriber.instance_exec(event, &handler)
              end
            end

            def eventable_guarded_callable_handler(handler)
              proc do |subscriber, event|
                next unless subscriber.eventable_event_object_matches?(event)

                handler.call(event)
              end
            end

            def eventable_register_event_buses!
              ::Plugins::Models::Concerns::Eventable::SubscribesToEvents.register_unload_callback(self)
              return if instance_variable_defined?(:@eventable_subscriptions)

              registrations = []
              begin
                eventable_subscription_buses.uniq.each do |bus|
                  registration = SubscriptionRegistration.new(eventable_bus.instance(bus, init: true))
                  registrations << registration
                  subscriber = new
                  eventable_subscription_definitions.each do |definition|
                    next unless definition[:bus] == bus

                    adapter = definition[:adapter]
                    callback = lambda do |event|
                      if adapter.is_a?(Symbol)
                        subscriber.public_send(adapter, event)
                      else
                        adapter.call(subscriber, event)
                      end
                    end
                    case definition[:kind]
                    when :event
                      registration.subscribe(definition[:event_name], &callback)
                    when :matcher
                      registration.subscribe_with_matcher(definition[:matcher], &callback)
                    when :all
                      registration.subscribe_to_all(&callback)
                    end
                  end
                  subscriber.subscribe_to(registration)
                end
              rescue StandardError
                registrations.each(&:unsubscribe_all!)
                raise
              end
              instance_variable_set(:@eventable_subscriptions, registrations.flat_map do |registration|
                registration.subscriptions.map { |subscription| [registration.bus, subscription] }
              end)
            end

            def eventable_unregister_event_buses!
              Array(instance_variable_get(:@eventable_subscriptions)).each do |bus, subscription|
                bus.unsubscribe(subscription)
              end
              remove_instance_variable(:@eventable_subscriptions) if
                instance_variable_defined?(:@eventable_subscriptions)
            end
          end

          module InstanceMethods
            def initialize(*args)
              super(*args) if defined?(super)
              @id = SecureRandom.hex(6)
            end

            def eventable_event_object_matches?(event)
              klasses = self.class.eventable_event_object_classes
              return true if klasses.blank?

              event_object = event.respond_to?(:[]) ? event[:object] : nil
              klasses.any? do |klass|
                resolved_klass =
                  case klass
                  when String
                    klass.safe_constantize
                  when Symbol
                    klass.to_s.safe_constantize
                  else
                    klass
                  end

                resolved_klass && event_object.is_a?(resolved_klass)
              end
            end
          end
        end
      end
    end
  end
end
