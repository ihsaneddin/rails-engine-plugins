require "spec_helper"
require "active_support/all"
require "set"
require File.expand_path("../../../lib/plugins/decorators/smart_send", __dir__)
require File.expand_path("../../../lib/plugins/decorators/inheritables", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/decorators/support", __dir__)

RSpec.describe Plugins::Decorators::Inheritables do
  let(:base_class) { Dummy::PluginsDecoratorsSupport::InheritablesBase }
  let(:subclass) { Dummy::PluginsDecoratorsSupport::InheritablesChild }

  it "deep copies inheritable class attributes to subclasses" do
    subclass.settings[:nested][:enabled] = false
    subclass.tags << "child"

    expect(base_class.settings[:nested][:enabled]).to eq(true)
    expect(base_class.tags).to eq(Set.new(["plugins"]))
  end

  it "inherits tracked singleton methods" do
    expect(subclass.flag).to eq("base")
  end
end
