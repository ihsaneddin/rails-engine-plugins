require "spec_helper"
require "active_support/all"
require "omnes"
require File.expand_path("../../../lib/plugins/configuration/bus", __dir__)

RSpec.describe Plugins::Configuration::Bus do
  before do
    described_class.registered_buses.clear
    described_class.class_variable_set(:@@blocks, [])
    described_class.clear_all = false
  end

  it "creates and returns named bus instances" do
    bus = described_class.instance(:plugins, init: true)

    expect(bus).to be_a(Omnes::Bus)
    expect(described_class.registered_buses[:plugins]).to eq(bus)
  end

  it "registers events and reports registration state" do
    described_class.instance(:plugins, init: true)

    described_class.register(:plugins, :created)

    expect(described_class.registered?(:plugins, :created)).to eq(true)
  end

  it "safe subscribes by auto-registering the event first" do
    described_class.instance(:plugins, init: true)
    payloads = []

    described_class.safe_subscribe(:plugins, :created) { |event| payloads << event.payload }
    described_class.publish(:plugins, :created, payload: { ok: true })

    expect(payloads).to include({ payload: { ok: true } })
  end

  it "runs deferred setup blocks via apply_setup!" do
    described_class.setup do
      instance(:plugins, init: true)
      register(:plugins, :created)
    end

    described_class.apply_setup!

    expect(described_class.registered?(:plugins, :created)).to eq(true)
  end
end
