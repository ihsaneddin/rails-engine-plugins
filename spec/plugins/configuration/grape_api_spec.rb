require "spec_helper"
require "active_support/all"
require "mutex_m"
require File.expand_path("../../../lib/plugins/configuration/callbacks", __dir__)
require File.expand_path("../../../lib/plugins/configuration/grape_api", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/configuration/support", __dir__)

RSpec.describe Plugins::Configuration::GrapeApi do
  describe Plugins::Configuration::GrapeApi::Pagination::Configuration do
    it "extracts page and per_page params by default" do
      config = described_class.new

      expect(config.page_param(page: 4)).to eq(4)
      expect(config.per_page_param(per_page: 15)).to eq(15)
    end

    it "raises on an unknown paginator" do
      config = described_class.new

      expect { config.paginator = :unknown }.to raise_error(StandardError, /Unknown paginator/)
    end
  end

  describe "configuration core" do
    it "supports authenticate!, authorize!, and draw_callbacks" do
      callback_set = Dummy::PluginsConfigurationSupport::GrapeApiCallbackSetHost
      callback_set.base = "Api"
      mod = Dummy::PluginsConfigurationSupport::GrapeApiCoreHost

      mod.callback_set = callback_set
      mod.base_api_namespace = "Api"
      mod.base_endpoint_class = "base"
      mod.authenticate! { :user }
      mod.authorize! { true }

      expect(mod.authenticate.call).to eq(:user)
      expect(mod.authorize.call).to eq(true)

      expect do
        mod.draw_callbacks do
          endpoint :users do
            callback :model_klass, "User"
          end
        end
      end.not_to raise_error
    end
  end
end
