# frozen_string_literal: true

require "spec_helper"
require "active_support/all"
require "omnes"
require File.expand_path("../../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../../lib/plugins/configuration/bus", __dir__)

module Plugins
  def self.decorators
    Decorators
  end
end

require ENV.fetch("EVENTABLE_SOURCE_PATH",
  File.expand_path("../../../../lib/plugins/models/concerns/eventable", __dir__))

RSpec.describe Plugins::Models::Concerns::Eventable::SubscribesToEvents do
  let(:first_bus_name) { :eventable_lifecycle_first }
  let(:second_bus_name) { :eventable_lifecycle_second }
  let(:first_bus) { Plugins::Configuration::Bus.instance(first_bus_name, init: true) }
  let(:second_bus) { Plugins::Configuration::Bus.instance(second_bus_name, init: true) }
  let(:unload_callbacks) { {} }

  before do
    first_bus.register(:changed)
    second_bus.register(:changed)
    stub_const("EventableLifecycleCalls", [])
    loader = Object.new
    allow(loader).to receive(:on_unload) do |name, &callback|
      unload_callbacks[name] = callback
    end
    stub_const("Rails", Module.new)
    application = Struct.new(:autoloaders).new(Struct.new(:main).new(loader))
    Rails.define_singleton_method(:application) { application }
  end

  after do
    %w[PluginsEventableLifecycleSubscriber PluginsEventableBusScopedSubscriber
      PluginsEventableFailureSubscriber PluginsEventableMixedSubscriber
      PluginsEventableDirectSubscriber PluginsEventableRepeatSubscriber
      PluginsEventablePartialSubscriber PluginsEventableAllSubscriber].each do |name|
      next unless Object.const_defined?(name, false)

      klass = Object.const_get(name, false)
      unload_callbacks[name]&.call(klass, "spec")
      described_class.eventable_subsciber_classes.delete(klass)
      Object.send(:remove_const, name)
    end
    Plugins::Configuration::Bus.registered_buses.delete(first_bus_name)
    Plugins::Configuration::Bus.registered_buses.delete(second_bus_name)
  end

  it "unloads block and callable declarations without removing another listener" do
    first_bus.subscribe(:changed) { EventableLifecycleCalls << :independent }
    callable = ->(_event) { EventableLifecycleCalls << :callable }
    stub_const("EventableLifecycleCallable", callable)
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableDirectSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event(:changed, bus: :eventable_lifecycle_first) do |_event|
          EventableLifecycleCalls << :block
        end
        on_event :changed, handler: EventableLifecycleCallable, bus: :eventable_lifecycle_first
      end
    RUBY
    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[independent block callable])

    klass = PluginsEventableDirectSubscriber
    unload_callbacks.fetch(klass.name).call(klass, "spec")
    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[independent block callable independent])
    expect(first_bus.subscriptions.length).to eq(1)
  end

  it "unloads an all-event subscriber without removing an independent listener" do
    first_bus.subscribe(:changed) { EventableLifecycleCalls << :independent }
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableAllSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_all_events handler: :receive, bus: :eventable_lifecycle_first,
          matcher: proc { true }

        def receive(_event)
          EventableLifecycleCalls << :all_event
        end
      end
    RUBY

    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[independent all_event])

    klass = PluginsEventableAllSubscriber
    unload_callbacks.fetch(klass.name).call(klass, "spec")
    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[independent all_event independent])
    expect(first_bus.subscriptions.length).to eq(1)
  end

  it "keeps repeated registration idempotent until explicit unregister" do
    first_bus.subscribe(:changed) { EventableLifecycleCalls << :independent }
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableRepeatSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_lifecycle_first

        def receive(_event)
          EventableLifecycleCalls << :subscriber
        end
      end
    RUBY
    klass = PluginsEventableRepeatSubscriber
    klass.eventable_register_event_buses!
    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[independent subscriber])
    expect(first_bus.subscriptions.length).to eq(2)

    klass.eventable_unregister_event_buses!
    klass.eventable_register_event_buses!
    EventableLifecycleCalls.clear
    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[independent subscriber])
    expect(first_bus.subscriptions.length).to eq(2)
  end

  it "rolls back only its own subscriptions if registration stops on a later bus" do
    first_bus.subscribe(:changed) { EventableLifecycleCalls << :independent_first }
    second_bus.subscribe(:changed) { EventableLifecycleCalls << :independent_second }
    allow(second_bus).to receive(:subscribe_with_matcher).and_raise("registration rejected")

    expect do
      Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        class PluginsEventablePartialSubscriber
          include Plugins::Models::Concerns::Eventable::SubscribesToEvents
          on_event :changed, handler: :receive, bus: :eventable_lifecycle_first
          on_event :changed, handler: :receive, bus: :eventable_lifecycle_second

          def receive(_event)
            EventableLifecycleCalls << :partial
          end
        end
      RUBY
    end.to raise_error("registration rejected")
    expect(first_bus.subscriptions.length).to eq(1)
    expect(second_bus.subscriptions.length).to eq(1)
    expect(described_class.eventable_subsciber_classes).not_to include(PluginsEventablePartialSubscriber)
  end

  it "unloads only the declaring subscriber while preserving an independent listener" do
    first_bus.subscribe(:changed) { EventableLifecycleCalls << :independent }
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableLifecycleSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_lifecycle_first

        def receive(_event)
          EventableLifecycleCalls << :old
        end
      end
    RUBY
    original = PluginsEventableLifecycleSubscriber
    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[independent old])

    unload_callbacks.fetch(original.name).call(original, "spec")
    expect(first_bus.subscriptions.length).to eq(1)
    Object.send(:remove_const, original.name)
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableLifecycleSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_lifecycle_first

        def receive(_event)
          EventableLifecycleCalls << :replacement
        end
      end
    RUBY

    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[independent old independent replacement])
    expect(first_bus.subscriptions.length).to eq(2)
  end

  it "keeps Eventable declarations on their declared buses and direct Omnes handlers usable" do
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableBusScopedSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :first, bus: :eventable_lifecycle_first
        on_event :changed, handler: :second, bus: :eventable_lifecycle_second

        def first(_event)
          EventableLifecycleCalls << :first
        end

        def second(_event)
          EventableLifecycleCalls << :second
        end
      end
    RUBY
    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    Plugins::Configuration::Bus.publish(second_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[first second])

    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableMixedSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        handle :changed, with: :direct
        on_event :changed, handler: :eventable, bus: :eventable_lifecycle_first

        def direct(_event)
          EventableLifecycleCalls << :direct
        end

        def eventable(_event)
          EventableLifecycleCalls << :eventable
        end
      end
    RUBY
    EventableLifecycleCalls.clear
    Plugins::Configuration::Bus.publish(first_bus_name, :changed)
    expect(EventableLifecycleCalls).to eq(%i[first eventable direct])
  end

  it "propagates a handler error without invoking the participant twice" do
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableFailureSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_lifecycle_first

        def receive(_event)
          EventableLifecycleCalls << :invoked
          raise ArgumentError, "participant rejected"
        end
      end
    RUBY
    expect { Plugins::Configuration::Bus.publish(first_bus_name, :changed) }
      .to raise_error(ArgumentError, "participant rejected")
    expect(EventableLifecycleCalls).to eq([:invoked])
  end
end
