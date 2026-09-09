require "spec_helper"
require "active_support/all"
require File.expand_path("../../../lib/plugins/grape", __dir__)

RSpec.describe Plugins::Grape::AddSetupGuard do
  def build_grape_api(version)
    stub_const("Grape", Module.new)
    Grape.const_set(:VERSION, version)

    Class.new do
      class << self
        attr_reader :recorded_setups

        def add_setup(method, *args, &block)
          (@recorded_setups ||= []) << [method, args, block]
          :recorded
        end
      end
    end.tap do |api_class|
      Grape.const_set(:API, api_class)
      Plugins::Grape.install_add_setup_guard(api_class, grape_version: version)
    end
  end

  it "does not record Ruby method lifecycle callbacks on Grape 1.6.2" do
    api_class = build_grape_api("1.6.2")

    expect(api_class.add_setup(:method_added)).to be_nil
    expect(api_class.add_setup(:singleton_method_added)).to be_nil
    expect(api_class.recorded_setups).to be_nil
  end

  it "delegates every other setup call with its arguments, block, and return value" do
    api_class = build_grape_api("1.6.2")
    setup_block = proc { :setup }

    expect(api_class.add_setup(:before, :authorization, &setup_block)).to eq(:recorded)
    expect(api_class.recorded_setups).to eq(
      [[:before, [:authorization], setup_block]]
    )
  end

  it "does not install the compatibility guard for other Grape versions" do
    api_class = build_grape_api("1.6.1")

    expect(api_class.add_setup(:method_added)).to eq(:recorded)
    expect(api_class.recorded_setups.map(&:first)).to eq([:method_added])
    expect(api_class.singleton_class.ancestors).not_to include(described_class)
  end

  it "installs the compatibility guard only once" do
    api_class = build_grape_api("1.6.2")

    Plugins::Grape.install_add_setup_guard(api_class, grape_version: "1.6.2")

    expect(api_class.singleton_class.ancestors.count(described_class)).to eq(1)
  end
end
