require 'set'

module Plugins
  module Models
    module Concerns
      module Eventable

        extend ActiveSupport::Concern

        included do
          include PublishesEvents
          include SubscribesToEvents
        end

        # included do
        #   class_attribute :_instrumented_callbacks
        #   self._instrumented_callbacks = {}
        #   [ :before_validation, :after_validation, :before_save, :after_save, :before_create, :after_create, :before_update, :after_update, :before_destroy, :after_destroy ].each do  |kallback|
        #     class_eval <<-CODE, __FILE__, __LINE__ + 1
        #       def _callback_event_#{kallback}
        #         unless (self.class.instrumented_callbacks || []).include?('#{kallback.to_s}')
        #           self.class.events_config.instrument(type: self.class.event_base_name.demodulize.underscore.downcase + '.#{kallback}', payload: self)
        #           self.class.instrumented_callbacks= '#{kallback.to_s}'
        #         end
        #       end
        #     CODE
        #     send kallback, "_callback_event_#{kallback}".to_sym
        #   end
        # end

        # class_methods do

        #   def instrumented_callbacks
        #     self._instrumented_callbacks[self.name] ||= []
        #   end

        #   def instrumented_callbacks=(v)
        #     self._instrumented_callbacks[self.name] ||= []
        #     self._instrumented_callbacks[self.name] << v
        #   end

        #   def event_base_name
        #     self.name
        #   end

        # end

        module PublishesEvents
          def self.included(base)
            base.include(Plugins::Models::Concerns::Options::InheritableClassAttribute)
            base.inheritable_class_attribute :_event_publications
            base._event_publications ||= {}
            base.extend(ClassMethods)
            base.singleton_class.prepend(MethodOverrideTracker)
            base.instance_variable_set(:@_pending_event_wraps, Set.new)
            base.instance_variable_set(:@_method_wrapped, Set.new)
          end

          module ClassMethods
            def publishes_event(event_name, on: nil, bus: :default, prefix: nil)
              method_key = on&.to_sym || :manual
              prefix ||= name.demodulize.underscore

              self._event_publications ||= {}
              self._event_publications = _event_publications.deep_dup
              self._event_publications[method_key] ||= []

              self._event_publications[method_key] << {
                event_name: event_name.to_sym,
                bus: bus.to_sym,
                prefixes: [prefix]
              }

              Plugins::Configuration::Bus.instance(bus, init: true)
              Plugins::Configuration::Bus.register(bus, "#{prefix}.#{event_name}")

              # Defer wrapping until method is defined
              if method_key != :manual
                @_pending_event_wraps << method_key
              end
            end

            def _event_publications_for(method_name)
              _event_publications[method_name.to_sym] || []
            end

            def inherited(subclass)
              super(subclass)

              subclass_prefix = subclass.name.demodulize.underscore

              if subclass._event_publications
                subclass._event_publications.each do |_method, events|
                  events.each do |event|
                    event[:prefixes] ||= []
                    unless event[:prefixes].include?(subclass_prefix)
                      event[:prefixes] << subclass_prefix

                      bus = event[:bus] || :default
                      Plugins::Configuration::Bus.instance(bus, init: true)
                      Plugins::Configuration::Bus.register(bus, "#{subclass_prefix}.#{event[:event_name]}")
                    end
                  end
                end
              end
            end

            def wrap_method_with_event_publish(klass, method_name)
              return if klass.instance_variable_get(:@_method_wrapped).include?(method_name.to_sym)

              klass.instance_variable_get(:@_method_wrapped) << method_name.to_sym
              original = klass.instance_method(method_name)

              klass.define_method(method_name) do |*args, **kwargs, &block|
                result = original.bind(self).call(*args, **kwargs, &block)

                self.class._event_publications_for(method_name).each do |event_def|
                  event = event_def[:event_name].to_s
                  bus = event_def[:bus]
                  event_def[:prefixes].each do |prefix|
                    Plugins::Configuration::Bus.publish(bus, "#{prefix}.#{event}", target: self)
                  end
                end

                result
              end
            end
          end

          module MethodOverrideTracker
            def method_added(method_name)
              super

              return unless respond_to?(:_event_publications)

              pending = @_pending_event_wraps || Set.new
              return unless pending.include?(method_name)

              PublishesEvents::ClassMethods.wrap_method_with_event_publish(self, method_name)
              pending.delete(method_name)
            end
          end

          def publish_event(event_name, bus: :default, prefix: nil, **payload)
            prefix ||= self.class.name.demodulize.underscore
            Plugins::Configuration::Bus.instance(bus.to_sym, init: true)
            Plugins::Configuration::Bus.publish(bus.to_sym, "#{prefix}.#{event_name}", target: self, **payload)
          end
        end

        module SubscribesToEvents
          def self.included(base)
            base.extend(ClassMethods)
            base.include(Plugins::Models::Concerns::Options::InheritableClassAttribute)
            base.inheritable_class_attribute :_event_subscriptions
            base._event_subscriptions ||= []
          end

          module ClassMethods
            def on_event(bus:, event:, handler: nil, &block)
              self._event_subscriptions ||= []
              self._event_subscriptions = _event_subscriptions.dup

              self._event_subscriptions << {
                bus: bus.to_sym,
                event: event.to_s,
                handler: handler,
                block: block
              }
            end

            def register_event_subscriptions!
              @_event_subscriptions_registered ||= {}

              self._event_subscriptions.each do |sub|
                key = "#{sub[:bus]}:#{sub[:event]}"
                next if @_event_subscriptions_registered[key]

                Plugins::Configuration::Bus.instance(sub[:bus], init: true)
                Plugins::Configuration::Bus.register(sub[:bus], sub[:event])
                Plugins::Configuration::Bus.subscribe(sub[:bus], sub[:event]) do |payload|
                  target = payload[:target]

                  if sub[:handler]
                    target.send(sub[:handler], payload)
                  else
                    target.instance_exec(payload, &sub[:block])
                  end
                end

                @_event_subscriptions_registered[key] = true
              end
            end
          end
        end

      end
    end
  end
end