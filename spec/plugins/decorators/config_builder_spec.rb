require "spec_helper"
require "active_support/all"
require File.expand_path("../../../lib/plugins/models/concerns/config", __dir__)
require File.expand_path("../../../lib/plugins/decorators/config_builder", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/decorators/support", __dir__)

RSpec.describe Plugins::Decorators::ConfigBuilder do
  let(:host) { Dummy::PluginsDecoratorsSupport::ConfigBuilderHost }

  it "exposes config classes" do
    expect(host.config_class).to eq(Plugins::Models::Concerns::Config)
    expect(host.collection_config_class).to eq(Plugins::Models::Concerns::Config::Collection)
    expect(host.plugins_config).to eq(Plugins::Models::Concerns::Config)
    expect(host.plugins_collection_config).to eq(Plugins::Models::Concerns::Config::Collection)
  end

  it "builds config objects through the helper" do
    cfg = host.config_builder(name: "plugins")

    expect(cfg).to be_a(Plugins::Models::Concerns::Config)
    expect(cfg.values[:name]).to eq("plugins")
  end
end
