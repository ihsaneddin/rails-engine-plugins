require "spec_helper"
require "active_support/all"
require "set"
require File.expand_path("../../../lib/plugins/decorators/registered", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/decorators/support", __dir__)

RSpec.describe Plugins::Decorators::Registered do
  let(:registry) { Dummy::PluginsDecoratorsSupport::RegisteredRegistry }

  before do
    registry.registered_classes = Set.new
  end

  it "initializes a registered_classes set" do
    expect(registry.registered_classes).to be_a(Set)
    expect(registry.registered_classes).to be_empty
  end

  it "registers classes through register_class and <<" do
    first = Dummy::PluginsDecoratorsSupport::InheritablesBase
    second = Dummy::PluginsDecoratorsSupport::InheritablesChild

    registry.register_class(first)
    registry << second

    expect(registry.registered_classes).to include(first, second)
  end

  it "does not mutate previously captured set instances" do
    original = registry.registered_classes
    registry.register_class(Dummy::PluginsDecoratorsSupport::SmartSendHost)

    expect(original).to be_empty
    expect(registry.registered_classes).not_to equal(original)
  end
end
