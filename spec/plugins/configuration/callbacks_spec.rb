require "spec_helper"
require "active_support/all"
require "mutex_m"
require File.expand_path("../../../lib/plugins/configuration/callbacks", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/configuration/support", __dir__)

RSpec.describe Plugins::Configuration::Callbacks do
  describe Plugins::Configuration::Callbacks::Callback do
    it "builds a namespaced class name" do
      callback = described_class.new(:index, _namespace: %i[admin users], class: "records", base: "Api")

      expect(callback.class_name).to eq("Api::Admin::Users::Records")
    end

    it "executes the block against the given context" do
      context = Dummy::PluginsConfigurationSupport::CallbackContext.new

      callback = described_class.new(:index) { |value| mark(value) }
      callback.call(context, "ok")

      expect(context.value).to eq("ok")
    end
  end

  describe Plugins::Configuration::Callbacks::ComputedCallbacks do
    it "deduplicates callbacks" do
      callback = Plugins::Configuration::Callbacks::Callback.new(:index) {}
      computed = described_class.new([callback, callback])

      expect(computed.to_a).to eq([callback])
    end
  end

  describe Plugins::Configuration::Callbacks::Mapper do
    let(:callback_set_class) do
      Dummy::PluginsConfigurationSupport::CallbackSetHost
    end

    it "registers value-backed callbacks" do
      callback_set_class.draw_callbacks do
        callback :index, "presenter"
      end

      expect(callback_set_class.registered_callbacks["index"].call(Object.new)).to eq("presenter")
    end

    it "builds nested endpoint callback sets" do
      callback_set_class.draw_callbacks(base: "Api") do
        endpoint :users do
          callback :show do
            :ok
          end
        end
      end

      nested = callback_set_class.nested_classes["users"]
      expect(nested).not_to be_nil
      expect(nested.registered_callbacks["show"].class_name).to eq("Api::Users")
    end
  end
end
