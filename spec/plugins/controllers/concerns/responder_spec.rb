require "spec_helper"
require "active_record"
require "action_controller"
require "active_support/all"
require File.expand_path("../../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/config", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/api_resource", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/responder", __dir__)

module Plugins
  def self.decorators
    Decorators
  end
end

RSpec.describe Plugins::Controllers::Concerns::Responder do
  before do
    stub_const("ControllerResponderModel", Class.new do
      include Plugins::Models::Concerns::ApiResource

      api_resource "test", default: true do
        presenter "ModelConfiguredPresenter"
      end
    end)
  end

  def build_controller(&block)
    stub_const("Admin", Module.new) unless defined?(Admin)
    controller_class = Class.new(ActionController::Base)
    stub_const("Admin::ControllerResponderModelsController", controller_class)
    controller_class.include Plugins::Controllers::Concerns::Responder
    controller_class.class_eval do
      def get_value(key)
        key == :resource_context ? "test" : nil
      end

      def model_class_constant
        ControllerResponderModel
      end

      def controller_name
        "controller_responder_models"
      end
    end

    controller_class.class_eval(&block) if block
    controller_class.new
  end

  it "keeps the presenter set by the controller class before model configuration" do
    controller = build_controller do
      set_presenter_class "ControllerConfiguredPresenter"
    end

    expect(controller.presenter_klass).to eq("ControllerConfiguredPresenter")
  end

  it "falls back to the model api_resource presenter when the controller class has no presenter" do
    controller = build_controller

    expect(controller.presenter_klass).to eq("ModelConfiguredPresenter")
  end
end
