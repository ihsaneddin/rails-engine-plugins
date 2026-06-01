require "spec_helper"
require File.expand_path("../../lib/plugins/version", __dir__)

RSpec.describe Plugins do
  describe "VERSION" do
    it "defines the engine version" do
      expect(described_class::VERSION).to eq("2.0.0")
    end
  end
end
