require "spec_helper"
require "active_support/all"
require "mutex_m"
require File.expand_path("../../../lib/plugins/configuration/callbacks", __dir__)
require File.expand_path("../../../lib/plugins/configuration/api", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/configuration/support", __dir__)

RSpec.describe Plugins::Configuration::Api do
  describe Plugins::Configuration::Api::Pagination::Configuration do
    it "extracts page and per_page params by default" do
      config = described_class.new

      expect(config.page_param(page: 2)).to eq(2)
      expect(config.per_page_param(per_page: 25)).to eq(25)
    end

    it "supports custom page/per_page parameter keys" do
      config = described_class.new
      config.page_param = :current_page
      config.per_page_param = "limit"

      expect(config.page_param(current_page: 3)).to eq(3)
      expect(config.per_page_param("limit" => 10)).to eq(10)
    end

    it "raises on an unknown paginator" do
      config = described_class.new

      expect { config.paginator = :unknown }.to raise_error(StandardError, /Unknown paginator/)
    end
  end

  describe "configuration core" do
    it "supports authenticate! and draw_callbacks" do
      callback_set = Dummy::PluginsConfigurationSupport::ApiCallbackSetHost
      callback_set.base = "Api"
      mod = Dummy::PluginsConfigurationSupport::ApiCoreHost

      mod.callback_set = callback_set
      mod.base_api_namespace = "Api"
      mod.base_controller_class = "base_controller"
      mod.authenticate! { :user }

      expect(mod.authenticate.call).to eq(:user)

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
