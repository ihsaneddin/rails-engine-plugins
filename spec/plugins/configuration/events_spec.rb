require "spec_helper"
require "active_support/all"
require File.expand_path("../../../lib/plugins/configuration/events", __dir__)

RSpec.describe Plugins::Configuration::Events do
  it "builds a delegator with a namespace" do
    events = described_class.new("plugins")

    expect(events.namespace).to eq("plugins")
  end

  it "instruments namespaced events through the delegator" do
    events = described_class.new("plugins")
    received = nil

    ActiveSupport::Notifications.subscribe("plugins.created") do |*args|
      received = args.last
    end

    events.instrument(type: "created", payload: { id: 1 })

    expect(received).to eq({ id: 1 })
  end

  it "subscribes using the notification adapter payload contract" do
    delegator = described_class::Delegator.new("plugins")
    payloads = []

    delegator.subscribe("updated") { |payload| payloads << payload }
    delegator.instrument(type: "updated", payload: { ok: true })

    expect(payloads).to include({ ok: true })
  end
end
