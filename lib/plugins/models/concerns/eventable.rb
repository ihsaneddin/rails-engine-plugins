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

            tracer = TracePoint.new(:end) do |tp|
              if tp.self == base
                base.eventable_register_events!
                tracer.disable
              end
            end

            tracer.enable

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
                eventable_bus.register(bus_name.to_sym, [prefix, event_name].join("_").to_sym)
              end
            end

            def eventable_publish_event_for_method(method_name, **payload)
              events = self.eventable_events[method_name.to_sym] || []
              events.each do |eb|
                eb[:prefixes].each do |prefix|
                  eventable_bus.instance(eb[:bus], init: true)
                  eventable_bus.publish(eb[:bus], [prefix, eb[:event_name]].join("_").to_sym, **payload)
                end
              end
            end

            def eventable_register_events!
              self.eventable_events.each_value do |events|
                events.each do |eb|
                  eb[:prefixes].each do |prefix|
                    eventable_bus.instance(eb[:bus], init: true)
                    eventable_bus.register(eb[:bus], [prefix, eb[:event_name]].join("_").to_sym)
                  end
                end
              end
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

              tracer = TracePoint.new(:end) do |tp|
                if tp.self == subclass
                  subclass.eventable_register_events!
                  tracer.disable
                end
              end

              tracer.enable
            end
          end

          def publish_event(event_name, bus: nil, prefix: nil, **payload)
            prefix ||= self.class.name.demodulize.underscore
            bus ||= self.class.eventable_bus_name || :default
            event_name = [prefix, event_name].map(&:to_s).compact.join("_").to_sym
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

          def self.<<(base)
            @@eventable_subsciber_classes << base
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
                base.eventable_subscription_buses = []
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
                    base.eventable_register_event_buses!
                    tracer.disable
                  end
                end

                tracer.enable
              end
            end.new
          end

          module ClassMethods
            def on_event(*args, &block)
              opts = args.extract_options!
              events = args
              bus = opts[:bus] || :default
              handler = opts[:handler] || block

              eventable_bus.instance(bus.to_sym, init: true)

              case handler
              when Proc
                events.each do |event_name|
                  eventable_bus.safe_subscribe(bus.to_sym, event_name, &handler)
                end
              when String, Symbol
                events.each do |event_name|
                  eventable_bus.register(bus.to_sym, event_name) unless eventable_bus.registered?(bus.to_sym, event_name)
                  handle event_name, with: handler.to_sym
                end
                eventable_subscription_buses << bus unless eventable_subscription_buses.include?(bus)
              else
                events.each do |event_name|
                  eventable_bus.safe_subscribe(bus.to_sym, event_name, handler)
                end
              end
            end

            def on_matched_event(matcher, **opts, &block)
              handler = opts[:handler] || block
              bus = opts[:bus] || :default

              case handler
              when Proc
                eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, &handler)
              when String, Symbol
                handle_with_matcher matcher, with: handler.to_sym
                eventable_subscription_buses << bus unless eventable_subscription_buses.include?(bus)
              else
                eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, handler)
              end
            end

            def on_all_events(**opts, &block)
              handler = opts[:handler] || block
              bus = opts[:bus] || :default
              matcher = opts[:matcher]

              case handler
              when Proc
                eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, &handler)
              when String, Symbol
                handle_with_matcher matcher, with: handler.to_sym
                eventable_subscription_buses << bus unless eventable_subscription_buses.include?(bus)
              else
                eventable_bus.subscribe_to_all(bus.to_sym, matcher, handler)
              end
            end

            def eventable_register_event_buses!
              eventable_subscription_buses.uniq.each do |bus|
                bus_obj = eventable_bus.instance(bus, init: true)
                new.subscribe_to(bus_obj)
              end
            end
          end

          module InstanceMethods
            def initialize(*args)
              super(*args) if defined?(super)
              @id = SecureRandom.hex(6)
            end
          end
        end
      end
    end
  end
end

# require 'set'

# module Plugins
#   module Models
#     module Concerns
#       module Eventable

#         extend ActiveSupport::Concern

#         included do
#           class_attribute :_instrumented_callbacks
#           self._instrumented_callbacks = {}
#           [ :before_validation, :after_validation, :before_save, :after_save, :before_create, :after_create, :before_update, :after_update, :before_destroy, :after_destroy ].each do  |kallback|
#             class_eval <<-CODE, __FILE__, __LINE__ + 1
#               def _callback_event_#{kallback}
#                 unless (self.class.instrumented_callbacks || []).include?('#{kallback.to_s}')
#                   self.class.events_config.instrument(type: self.class.event_base_name.demodulize.underscore.downcase + '.#{kallback}', payload: self)
#                   self.class.instrumented_callbacks= '#{kallback.to_s}'
#                 end
#               end
#             CODE
#             send kallback, "_callback_event_#{kallback}".to_sym
#           end
#         end

#         class_methods do

#           def instrumented_callbacks
#             self._instrumented_callbacks[self.name] ||= []
#           end

#           def instrumented_callbacks=(v)
#             self._instrumented_callbacks[self.name] ||= []
#             self._instrumented_callbacks[self.name] << v
#           end

#           def event_base_name
#             self.name
#           end

#         end

#         module PublishesEvents

#           mattr_accessor :eventable_publishes_events_classes
#           @@eventable_publishes_events_classes = []

#           def self.<<(base)
#             @@eventable_publishes_events_classes << base unless @@eventable_publishes_events_classes.include?(base)
#           end

#           def self.eventable_register_events
#             @@eventable_publishes_events_classes.each do |klass|
#               klass.eventable_register_events!
#               klass.descendants.each(&:eventable_register_events!)
#             end
#           end

#           def self.included(base)
#             return if base.instance_variable_defined?(:@_eventable_loaded)

#             base.include Plugins.decorators.inheritables.singleton_methods
#             base.include Plugins::Decorators.method_decorators
#             base.inheritable_class_attribute :eventable_events
#             base.inheritable_class_attribute :eventable_bus_name
#             base.eventable_events ||= {}
#             base.eventable_bus_name = base.name.demodulize.underscore.to_sym
#             base.define_inheritable_singleton_method :eventable_bus do
#               Plugins::Configuration::Bus
#             end
#             base.define_method :eventable_bus do
#               self.class.eventable_bus
#             end

#             self << base

#             tracer = TracePoint.new(:end) do |tp|
#               if tp.self == base
#                 base.eventable_register_events!
#                 tracer.disable
#               end
#             end

#             tracer.enable

#             base.define_method_decorator :eventable_publish_event_decorator do |method_name, original, *args, block, **opts|
#               result = original.call(*args, &block)
#               if result
#                 skip_if = opts[:skip_if]
#                 if skip_if.is_a?(Proc)
#                   skip_if = instance_exec(&skip_if)
#                 end
#                 unless skip_if
#                   payload = opts[:payload]
#                   if payload.is_a?(Proc)
#                     payload = instance_exec(&payload)
#                   end
#                   payload ||= { object: self }
#                   self.class.eventable_publish_event_for_method(method_name, **(payload.is_a?(Hash) ? payload : {object: payload}))
#                 end
#               end
#               result
#             end

#             base.extend ClassMethods
#             base.instance_variable_set(:@_eventable_loaded, true)
#           end

#           module ClassMethods
#             def publishes_event(event_name, on:, bus: nil, prefix: nil, payload: nil, skip_if: false, &block)
#               method_key = on&.to_sym
#               prefix ||= name.demodulize.underscore
#               bus ||= eventable_bus_name || :default
#               payload ||= block

#               self.eventable_events = eventable_events.deep_dup
#               self.eventable_events[method_key] ||= []

#               self.eventable_events[method_key] << {
#                 event_name: event_name.to_sym,
#                 bus: bus.to_sym,
#                 prefixes: [prefix],
#               }

#               decorate_method( on, with: :eventable_publish_event_decorator, **{ payload: payload, skip_if: skip_if })
#             end

#             def register_events *args
#               opts = args.extract_options!
#               events = args
#               bus_name = opts[:bus] || eventable_bus_name
#               prefix = opts[:prefix] || name.demodulize.underscore
#               events.each do |event_name|
#                 eventable_bus.instance(bus_name.to_sym, init: true)
#                 eventable_bus.register(bus_name.to_sym, [prefix, event_name].join("_").to_sym)
#               end
#             end

#             def eventable_publish_event_for_method(method_name, **payload)
#               events = self.eventable_events[method_name.to_sym] || []
#               events.each do |eb|
#                 eb[:prefixes].each do |prefix|
#                   eventable_bus.instance(eb[:bus], init: true)
#                   eventable_bus.publish(eb[:bus], [prefix, eb[:event_name]].join("_").to_sym, **payload)
#                 end
#               end
#             end

#             def eventable_register_events!
#               self.eventable_events.each_value do |events|
#                 events.each do |eb|
#                   eb[:prefixes].each do |prefix|
#                     eventable_bus.instance(eb[:bus], init: true)
#                     eventable_bus.register(eb[:bus], [prefix, eb[:event_name]].join("_").to_sym)
#                   end
#                 end
#               end
#             end

#             def inherited(subclass)
#               super(subclass)
#               subclass_prefix = subclass.name.demodulize.underscore
#               if subclass.eventable_events
#                 subclass.eventable_events.each do |_method, events|
#                   events.each do |event|
#                     event[:prefixes] ||= []
#                     unless event[:prefixes].include?(subclass_prefix)
#                       event[:prefixes] << subclass_prefix
#                     end
#                   end
#                 end
#               end

#               tracer = TracePoint.new(:end) do |tp|
#                 if tp.self == subclass
#                   subclass.eventable_register_events!
#                   tracer.disable
#                 end
#               end

#               tracer.enable
#             end
#           end

#           def publish_event(event_name, bus: nil, prefix: nil, **payload)
#             prefix ||= self.class.name.demodulize.underscore
#             bus ||= self.class.eventable_bus_name || :default
#             event_name = [prefix, event_name].map(&:to_s).compact.join("_").to_sym
#             eventable_bus.instance(bus.to_sym, init: true)
#             eventable_bus.register(bus.to_sym, event_name.to_sym) unless eventable_bus.registered?(bus.to_sym, event_name.to_sym)
#             eventable_bus.publish(bus.to_sym, event_name, **payload)
#           end

#         end

#         module SubscribesToEvents

#           mattr_accessor :eventable_subsciber_classes
#           @@eventable_subsciber_classes = []

#           def self.<<(base)
#             @@eventable_subsciber_classes << base
#           end

#           def self.eventable_register_event_buses!
#             @@eventable_subsciber_classes.eachd do |klass|
#               klass.eventable_register_event_buses!
#               klass.descendants.each(&:eventable_register_event_buses!)
#             end
#           end

#           def self.included(base)
#             base.include(self.[])
#           end

#           def self.[](**options)
#             Class.new(Module) do
#               define_method(:included) do |base|
#                 base.include(::Omnes::Subscriber[**options])
#                 base.include Plugins.decorators.inheritables.singleton_methods
#                 base.inheritable_class_attribute :eventable_subscription_buses
#                 base.eventable_subscription_buses = []
#                 base.extend(ClassMethods)
#                 base.include(InstanceMethods)
#                 base.define_inheritable_singleton_method :eventable_bus do
#                   Plugins::Configuration::Bus
#                 end
#                 base.define_method :eventable_bus do
#                   self.class.eventable_bus
#                 end
#                 base.attr_reader :id
#                 ::Plugins::Models::Concerns::Eventable::SubscribesToEvents << base

#                 tracer = TracePoint.new(:end) do |tp|
#                   if tp.self == base
#                     base.eventable_register_event_buses!
#                     tracer.disable
#                   end
#                 end
#                 tracer.enable
#               end
#             end.new
#           end

#         module ClassMethods

#           def on_event(*args, &block)
#             opts = args.extract_options!
#             events = args
#             bus = opts[:bus] || :default
#             handler = opts[:handler] || block
#             eventable_bus.instance(bus.to_sym, init: true)
#             case handler
#             when Proc
#               events.each do |event_name|
#                 eventable_bus.safe_subscribe(bus.to_sym, event_name, &handler)
#               end
#             when String,Symbol
#               events.each do |event_name|
#                 eventable_bus.register(bus.to_sym, event_name) unless eventable_bus.registered?(bus.to_sym, event_name)
#                 handle event_name, with: handler.to_sym
#               end
#               eventable_subscription_buses << bus unless eventable_subscription_buses.include?(bus)
#             else
#               events.each do |event_name|
#                 eventable_bus.safe_subscribe(bus.to_sym, event_name, handler)
#               end
#             end
#           end

#           def on_matched_event(matcher, **opts, &block)
#             handler = opts[:handler] || block
#             bus = opts[:bus] || :default
#             case handler
#             when Proc
#               eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, &handler)
#             when String,Symbol
#               handle_with_matcher matcher, with: handler.to_sym
#               eventable_subscription_buses << bus unless eventable_subscription_buses.include?(bus)
#             else
#               eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, handler)
#             end
#           end

#           def on_all_events **opts, &block
#             handler = opts[:handler] || block
#             bus = opts[:bus] || :default
#             matcher = opts[:matcher]
#             case handler
#             when Proc
#               eventable_bus.subscribe_with_matcher(bus.to_sym, matcher, &handler)
#             when String,Symbol
#               handle_with_matcher matcher, with: handler.to_sym
#               eventable_subscription_buses << bus unless eventable_subscription_buses.include?(bus)
#             else
#               eventable_bus.subscribe_to_all(bus.to_sym, matcher, handler)
#             end
#           end

#           def eventable_register_event_buses!
#             eventable_subscription_buses.uniq.each do |bus|
#               bus_obj = eventable_bus.instance(bus, init: true)
#               new.subscribe_to(bus_obj)
#             end
#           end
#         end
#         end

#         module InstanceMethods

#           def initialize *args
#             super(*args) if defined?(super)
#             @id = SecureRandom.hex(6)
#           end

#         end

#       end
#     end
#   end
# end