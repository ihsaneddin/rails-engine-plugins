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

require File.expand_path("../../../../lib/plugins/models/concerns/eventable", __dir__)

RSpec.describe Plugins::Models::Concerns::Eventable::SubscribesToEvents do
  let(:bus_name) { :eventable_reload_contract }
  let(:bus) { Plugins::Configuration::Bus.instance(bus_name, init: true) }
  let(:unload_callbacks) { {} }
  let(:application_holder) { {} }

  before do
    bus.register(:changed)
    stub_const("EventableReloadCalls", [])
    loader = Object.new
    allow(loader).to receive(:on_unload) do |cpath, &callback|
      unload_callbacks[cpath] = callback
    end
    stub_const("Rails", Module.new)
    autoloaders = Struct.new(:main).new(loader)
    holder = application_holder
    holder[:current] = Struct.new(:autoloaders).new(autoloaders)
    Rails.define_singleton_method(:application) { holder[:current] }
    Rails.define_singleton_method(:autoloaders) { holder[:current].autoloaders }
  end

  after do
    %i[PluginsEventableReloadContractSubscriber PluginsEventableDirectContractSubscriber
      PluginsEventableMatcherContractSubscriber PluginsEventableEarlyContractSubscriber
      PluginsEventableFilteredContractSubscriber PluginsEventablePartialBusContractSubscriber
      PluginsEventablePartialDefinitionContractSubscriber
      PluginsEventableMultiBusContractSubscriber PluginsEventableOmnesContractSubscriber
      PluginsEventableRepeatContractSubscriber PluginsEventableErrorContractSubscriber].each do |name|
      next unless Object.const_defined?(name, false)

      declaring_class = Object.const_get(name, false)
      unload_callbacks[name.to_s]&.call(declaring_class, "synthetic")
      described_class.eventable_subsciber_classes.delete(declaring_class)
      Object.send(:remove_const, name)
    end
    Plugins::Configuration::Bus.registered_buses.delete(bus_name)
    Plugins::Configuration::Bus.registered_buses.delete(:eventable_reload_contract_failure)
    Plugins::Configuration::Bus.registered_buses.delete(:eventable_reload_contract_second)
  end

  it "replaces only a reloaded method subscriber and preserves an independent listener" do
    bus.subscribe(:changed) { EventableReloadCalls << :independent }
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableReloadContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_reload_contract

        def receive(_event)
          EventableReloadCalls << :old
        end
      end
    RUBY
    old_class = PluginsEventableReloadContractSubscriber

    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[independent old])

    unload_callbacks.fetch(old_class.name).call(old_class, "synthetic")
    expect(bus.subscriptions.length).to eq(1)
    expect(described_class.eventable_subsciber_classes).not_to include(old_class)
    Object.send(:remove_const, old_class.name)
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableReloadContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_reload_contract

        def receive(_event)
          EventableReloadCalls << :new
        end
      end
    RUBY

    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(bus.subscriptions.length).to eq(2)
    expect(EventableReloadCalls).to eq(%i[independent old independent new])

    replacement = PluginsEventableReloadContractSubscriber
    unload_callbacks.fetch(replacement.name).call(replacement, "synthetic")
    expect(bus.subscriptions.length).to eq(1)
  end

  it "unsubscribes direct block and callable handlers without clearing other listeners" do
    bus.subscribe(:changed) { EventableReloadCalls << :independent }
    callable = Object.new
    callable.define_singleton_method(:call) { |_event| EventableReloadCalls << :callable }
    stub_const("EventableReloadCallable", callable)
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableDirectContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event(:changed, bus: :eventable_reload_contract) do |_event|
          EventableReloadCalls << :block
        end
        on_event :changed, handler: EventableReloadCallable, bus: :eventable_reload_contract
      end
    RUBY
    declaring_class = PluginsEventableDirectContractSubscriber

    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[independent block callable])

    unload_callbacks.fetch(declaring_class.name).call(declaring_class, "synthetic")
    expect(bus.subscriptions.length).to eq(1)
    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[independent block callable independent])
  end

  it "invokes a failing handler once and propagates its own ArgumentError" do
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableErrorContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_reload_contract

        def receive(_event)
          EventableReloadCalls << :invoked
          raise ArgumentError, "source action rejected"
        end
      end
    RUBY

    expect do
      Plugins::Configuration::Bus.publish(bus_name, :changed)
    end.to raise_error(ArgumentError, "source action rejected")
    expect(EventableReloadCalls).to eq([:invoked])
  end

  it "keeps each handler on its declared bus while preserving independent listeners" do
    second_bus_name = :eventable_reload_contract_second
    second_bus = Plugins::Configuration::Bus.instance(second_bus_name, init: true)
    second_bus.register(:changed)
    bus.subscribe(:changed) { EventableReloadCalls << :independent_first }
    second_bus.subscribe(:changed) { EventableReloadCalls << :independent_second }
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableMultiBusContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive_first, bus: :eventable_reload_contract
        on_event :changed, handler: :receive_second, bus: :eventable_reload_contract_second
        on_matched_event(->(event) { event.omnes_event_name == :changed },
          bus: :eventable_reload_contract) do |_event|
          EventableReloadCalls << :matched_first
        end
        on_all_events(bus: :eventable_reload_contract_second) do |_event|
          EventableReloadCalls << :all_second
        end

        def receive_first(_event)
          EventableReloadCalls << :first
        end

        def receive_second(_event)
          EventableReloadCalls << :second
        end
      end
    RUBY

    Plugins::Configuration::Bus.publish(bus_name, :changed)
    Plugins::Configuration::Bus.publish(second_bus_name, :changed)
    expect(EventableReloadCalls).to eq(
      %i[independent_first first matched_first independent_second second all_second]
    )

    declaring_class = PluginsEventableMultiBusContractSubscriber
    unload_callbacks.fetch(declaring_class.name).call(declaring_class, "synthetic")
    expect(bus.subscriptions.length).to eq(1)
    expect(second_bus.subscriptions.length).to eq(1)
  end

  it "binds matched and all-event handlers to the subscriber and removes them on unload" do
    bus.subscribe(:changed) { EventableReloadCalls << :independent }
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableMatcherContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_matched_event(->(event) { event.omnes_event_name == :changed },
          bus: :eventable_reload_contract) do |_event|
          EventableReloadCalls << :matched
        end
        on_all_events(bus: :eventable_reload_contract) do |_event|
          EventableReloadCalls << :all
        end
      end
    RUBY
    declaring_class = PluginsEventableMatcherContractSubscriber

    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[independent matched all])

    unload_callbacks.fetch(declaring_class.name).call(declaring_class, "synthetic")
    expect(bus.subscriptions.length).to eq(1)
    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[independent matched all independent])
  end

  it "preserves direct Omnes handler declarations alongside bus-scoped Eventable declarations" do
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableOmnesContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        handle :changed, with: :receive_direct
        on_event :changed, handler: :receive_eventable, bus: :eventable_reload_contract

        def receive_direct(_event)
          EventableReloadCalls << :direct
        end

        def receive_eventable(_event)
          EventableReloadCalls << :eventable
        end
      end
    RUBY

    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[eventable direct])
  end

  it "does not duplicate a subscriber when its public registration runs again" do
    bus.subscribe(:changed) { EventableReloadCalls << :independent }
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableRepeatContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_reload_contract

        def receive(_event)
          EventableReloadCalls << :subscriber
        end
      end
    RUBY

    PluginsEventableRepeatContractSubscriber.eventable_register_event_buses!
    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[independent subscriber])
    expect(bus.subscriptions.length).to eq(2)

    PluginsEventableRepeatContractSubscriber.eventable_unregister_event_buses!
    expect(bus.subscriptions.length).to eq(1)
    PluginsEventableRepeatContractSubscriber.eventable_register_event_buses!
    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[independent subscriber independent subscriber])
    expect(bus.subscriptions.length).to eq(2)
  end

  it "registers an early subscriber before the app loader exists and installs cleanup later" do
    initialized_application = application_holder[:current]
    application_holder[:current] = nil
    bus.subscribe(:changed) { EventableReloadCalls << :independent }
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableEarlyContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        on_event :changed, handler: :receive, bus: :eventable_reload_contract

        def receive(_event)
          EventableReloadCalls << :early
        end
      end
    RUBY
    declaring_class = PluginsEventableEarlyContractSubscriber
    expect(unload_callbacks).not_to have_key(declaring_class.name)
    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq(%i[independent early])

    application_holder[:current] = initialized_application
    described_class.install_unload_callbacks!
    unload_callbacks.fetch(declaring_class.name).call(declaring_class, "synthetic")
    expect(bus.subscriptions.length).to eq(1)
  end

  it "keeps a matched all-event handler bound to its declared object filter" do
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class PluginsEventableFilteredContractSubscriber
        include Plugins::Models::Concerns::Eventable::SubscribesToEvents
        event_object_is_a "String"
        on_all_events handler: :receive, bus: :eventable_reload_contract,
          matcher: proc { true }

        def receive(event)
          EventableReloadCalls << event[:object]
        end
      end
    RUBY

    Plugins::Configuration::Bus.publish(bus_name, :changed, object: 5)
    Plugins::Configuration::Bus.publish(bus_name, :changed, object: "allowed")
    expect(EventableReloadCalls).to eq(["allowed"])
  end

  it "leaves no subscriber callback when a later bus rejects registration" do
    bus.subscribe(:changed) { EventableReloadCalls << :independent }
    failing_bus = Plugins::Configuration::Bus.instance(:eventable_reload_contract_failure, init: true)
    failing_bus.register(:changed)
    failing_bus.subscribe(:changed) { EventableReloadCalls << :independent_failure }
    allow(failing_bus).to receive(:subscribe_with_matcher).and_raise("registration aborted")

    expect do
      Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        class PluginsEventablePartialBusContractSubscriber
          include Plugins::Models::Concerns::Eventable::SubscribesToEvents
          on_event :changed, handler: :receive, bus: :eventable_reload_contract
          on_event :changed, handler: :receive, bus: :eventable_reload_contract_failure

          def receive(_event)
            EventableReloadCalls << :partial
          end
        end
      RUBY
    end.to raise_error("registration aborted")

    expect(failing_bus).to have_received(:subscribe_with_matcher)
    Plugins::Configuration::Bus.publish(bus_name, :changed)
    Plugins::Configuration::Bus.publish(:eventable_reload_contract_failure, :changed)
    expect(EventableReloadCalls).to eq(%i[independent independent_failure])
    expect(bus.subscriptions.length).to eq(1)
    expect(failing_bus.subscriptions.length).to eq(1)
    expect(described_class.eventable_subsciber_classes).not_to include(PluginsEventablePartialBusContractSubscriber)
  end

  it "leaves no subscriber callback when a later definition fails on the same bus" do
    bus.register(:archived)
    bus.subscribe(:changed) { EventableReloadCalls << :independent }
    attempts = 0
    allow(bus).to receive(:subscribe_with_matcher).and_wrap_original do |original, *args, **kwargs, &block|
      attempts += 1
      raise "registration aborted" if attempts == 2

      original.call(*args, **kwargs, &block)
    end

    expect do
      Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        class PluginsEventablePartialDefinitionContractSubscriber
          include Plugins::Models::Concerns::Eventable::SubscribesToEvents
          on_event :changed, :archived, handler: :receive, bus: :eventable_reload_contract

          def receive(_event)
            EventableReloadCalls << :partial
          end
        end
      RUBY
    end.to raise_error("registration aborted")

    expect(attempts).to be >= 2
    Plugins::Configuration::Bus.publish(bus_name, :changed)
    expect(EventableReloadCalls).to eq([:independent])
    expect(bus.subscriptions.length).to eq(1)
    expect(described_class.eventable_subsciber_classes).not_to include(PluginsEventablePartialDefinitionContractSubscriber)
  end
end
