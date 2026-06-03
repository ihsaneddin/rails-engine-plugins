require "spec_helper"
require "action_controller"
require "action_dispatch"
require "plugins/routes"

RSpec.describe Plugins::Routes::Helpers do
  let(:routes) { ActionDispatch::Routing::RouteSet.new }

  it "accepts a block for nested resource routes" do
    ActionDispatch::Routing::Mapper.include described_class
    stub_const("AttachmentsController", Class.new(ActionController::Base))

    routes.draw do
      resourceful_routes :locations do
        resources :attachments, only: [:index]
      end
    end

    expect(routes.recognize_path("/locations/1/attachments", method: :get)).to include(
      controller: "attachments",
      action: "index",
      location_id: "1"
    )
  end
end
