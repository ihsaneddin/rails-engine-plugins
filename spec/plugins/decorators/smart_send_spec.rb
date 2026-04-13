require "spec_helper"
require "active_support/all"
require File.expand_path("../../../lib/plugins/decorators/smart_send", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/decorators/support", __dir__)

RSpec.describe Plugins::Decorators::SmartSend do
  let(:host) { Dummy::PluginsDecoratorsSupport::SmartSendHost.new }

  it "passes positional arguments" do
    expect(host.smart_send(:positional, ["a", "b"])).to eq(["a", "b"])
  end

  it "maps keyword arguments from a trailing hash" do
    expect(host.smart_send(:keyword, [{ required: "x", optional: "y" }])).to eq(["x", "y"])
  end

  it "supports mixed positional and keyword arguments" do
    expect(host.smart_send(:mixed, ["a", "b", { flag: true, extra: 1 }])).to eq(["a", "b", true, { extra: 1 }])
  end
end
