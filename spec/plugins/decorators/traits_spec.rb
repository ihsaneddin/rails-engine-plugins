require "spec_helper"
require "active_support/all"
require "set"
require File.expand_path("../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../lib/plugins/decorators/smart_send", __dir__)
require File.expand_path("../../../lib/plugins/decorators/inheritables", __dir__)
require File.expand_path("../../../lib/plugins/decorators/registered", __dir__)
require File.expand_path("../../../lib/plugins/decorators/traits", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/decorators/support", __dir__)

RSpec.describe Plugins::Decorators::Traits do
  let(:registry) { Dummy::PluginsDecoratorsSupport::TraitsRegistry }
  let(:host_class) { Dummy::PluginsDecoratorsSupport::TraitsHost }

  before do
    registry.register_class(host_class)
  end

  it "registers traits and defines instance and class flag methods" do
    trait = Dummy::PluginsDecoratorsSupport::SearchableTrait

    registry.register_trait(trait)

    expect(host_class).to respond_to(:searchable?)
    expect(host_class.searchable?).to eq(false)
    expect(host_class.new.searchable?).to eq(false)
  end

  it "extends class methods from a trait module" do
    trait = Dummy::PluginsDecoratorsSupport::MarkerTrait

    registry.register_trait(trait)

    expect(host_class.marker).to eq("ok")
  end
end
