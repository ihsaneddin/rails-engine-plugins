require "spec_helper"
require "active_support/all"
require "set"
require File.expand_path("../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../lib/plugins/decorators/smart_send", __dir__)
require File.expand_path("../../../lib/plugins/decorators/inheritables", __dir__)
require File.expand_path("../../../lib/plugins/models/concerns/options", __dir__)
require File.expand_path("../../../lib/plugins/decorators/method_decorators", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/decorators/support", __dir__)

RSpec.describe Plugins::Decorators::MethodDecorators do
  let(:host_class) { Dummy::PluginsDecoratorsSupport::MethodDecoratorsHost }

  it "wraps decorated methods with the registered decorator" do
    expect(host_class.new.perform("ok")).to eq(["tracked", :perform, "OK"])
  end

  it "supports decorating methods after definition" do
    klass = Dummy::PluginsDecoratorsSupport::MethodDecoratorsLateHost

    expect(klass.new.perform("go")).to eq("gogo!")
  end
end
