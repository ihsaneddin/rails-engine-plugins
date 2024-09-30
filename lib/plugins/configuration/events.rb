module Plugins
  module Configuration
    module Events

      class Delegator
        attr_reader :backend
        attr_reader :namespace

        def initialize(namespace: nil)
          @backend = ActiveSupport::Notifications
          @namespace = namespace
        end

        def configure(&block)
          raise ArgumentError, "must provide a block" unless block
          block.arity.zero? ? instance_eval(&block) : yield(self)
        end

        def subscribe(name, callable = nil, &block)
          callable ||= block
          # backend.subscribe name_with_namespace(name), NotificationAdapter.new(callable)
          backend.subscribe to_regexp(name), NotificationAdapter.new(callable)
        end

        def all(callable = nil, &block)
          callable ||= block
          subscribe nil, callable
        end

        def unsubscribe(name)
          backend.unsubscribe name
        end

        def instrument(payload:, type:)
          backend.instrument name_with_namespace(type), payload
        end

        class NotificationAdapter
          def initialize(subscriber)
            @subscriber = subscriber
          end

          def call(*args)
            payload = args.last
            @subscriber.call(payload)
          end
        end

        private

        def to_regexp(name)
          %r{^#{Regexp.escape name_with_namespace(name)}}
        end

        def name_with_namespace(name, delimiter: ".")
          [@namespace, name].compact.join(delimiter)
        end
      end

      class << self
        delegate :configure, :instrument, :namespace, :namespace=, to: :delegator

        def delegator(namespace=nil)
          @delegator ||= Delegator.new(namespace: namespace)
        end

      end
    end
  end
end
