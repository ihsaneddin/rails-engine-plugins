require "spec_helper"
require "active_support/all"
require File.expand_path("../../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/config", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/api_resource", __dir__)
require File.expand_path("../../../../lib/plugins/grape/concerns/responder", __dir__)

module Plugins
  def self.decorators
    Decorators
  end
end

RSpec.describe Plugins::Grape::Concerns::Responder do
  before do
    stub_const("GrapeResponderModel", Class.new do
      include Plugins::Models::Concerns::ApiResource

      grape_api_resource "test", default: true do
        presenter "ModelConfiguredPresenter"
      end
    end)
  end

  def build_endpoint(&block)
    endpoint_class = Class.new do
      include Plugins::Grape::Concerns::Responder
      include Plugins::Grape::Concerns::Responder::HelperMethods

      def class_context
        block_given? ? yield(self.class) : self.class
      end

      def get_value(key)
        key == :resource_context ? "test" : nil
      end

      def model_class_constant
        GrapeResponderModel
      end
    end

    endpoint_class.class_eval(&block) if block
    endpoint_class.new
  end

  it "keeps the presenter set by the Grape API class before model configuration" do
    endpoint = build_endpoint do
      set_presenter "ApiConfiguredPresenter"
    end

    expect(endpoint.get_context_presenter_name).to eq("ApiConfiguredPresenter")
  end

  it "falls back to the model grape_api_resource presenter when the API class has no presenter" do
    endpoint = build_endpoint

    expect(endpoint.get_context_presenter_name).to eq("ModelConfiguredPresenter")
  end
end
