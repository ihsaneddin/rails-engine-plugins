require "spec_helper"
require "active_support/all"
require "set"
require File.expand_path("../../../lib/plugins/configuration/events", __dir__)
require File.expand_path("../../../lib/plugins/configuration/callbacks", __dir__)
require File.expand_path("../../../lib/plugins/configuration/permissions", __dir__)
require File.expand_path("../../../lib/plugins/configuration/api", __dir__)
require File.expand_path("../../../lib/plugins/configuration/grape_api", __dir__)
require File.expand_path("../../../lib/plugins/configuration/bus", __dir__)
require File.expand_path("../../../lib/plugins/configuration/core", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/configuration/support", __dir__)

RSpec.describe Plugins::Configuration::Core do
  let(:config_module) { Dummy::PluginsConfigurationSupport::CoreHost }

  it "assigns default configuration objects when included" do
    expect(config_module.events).to be_a(Plugins::Configuration::Events)
    expect(config_module.api).to eq(Plugins::Configuration::Api)
    expect(config_module.grape_api).to eq(Plugins::Configuration::GrapeApi)
    expect(config_module.permission_set_class).to eq(Plugins::Configuration::Permissions::PermissionSet)
    expect(config_module.bus).to eq(Plugins::Configuration::Bus)
    expect(config_module.load_constants).to be_a(Set)
  end

  it "supports setup with instance_eval and yielded self" do
    config_module.setup do
      load_constant "String"
    end

    config_module.setup do |cfg|
      cfg.load_constant "Array"
    end

    expect(config_module.load_constants).to include("String", "Array")
  end

  it "loads registered constants" do
    config_module.load_constant "String"
    config_module.load_constant "Array"

    expect { config_module.load_constants! }.not_to raise_error
  end
end
