require "spec_helper"
require "active_support/all"
require File.expand_path("../../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/config", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/api_resource", __dir__)
require File.expand_path("../../../../lib/plugins/grape/concerns/resourceful", __dir__)

module Plugins
  def self.decorators
    Decorators
  end
end

RSpec.describe Plugins::Grape::Concerns::Resourceful do
  before do
    stub_const("GrapeResourcefulModel", Class.new do
      def self.where
        WhereScope.new
      end

      class WhereScope
        def not(_conditions)
          [:base_scope]
        end
      end
    end)
  end

  def build_endpoint(&block)
    endpoint_class = Class.new do
      include Plugins::Grape::Concerns::Resourceful
      include Plugins::Grape::Concerns::Resourceful::HelperMethods

      def class_context
        block_given? ? yield(self.class) : self.class
      end

      def params
        {}
      end

      def route
        nil
      end
    end

    endpoint_class.class_eval(&block) if block
    endpoint_class.new
  end

  def action_route_for(kind)
    Class.new do
      class << self
        attr_reader :registered_methods, :handler

        def route(methods, _path, _options, &block)
          @registered_methods = methods
          @handler = block
        end
      end
    end.tap do |route_class|
      route_class.extend(
        Plugins::Grape::Concerns::Resourceful::Events.const_get(kind)
      )
    end
  end

  def action_endpoint(model:, method:)
    Object.new.tap do |endpoint|
      endpoint.define_singleton_method(:selected_model) { model }
      endpoint.define_singleton_method(:params) { { integration_action: "consume" } }
      endpoint.define_singleton_method(:request) do
        Struct.new(:request_method).new(method)
      end
      endpoint.define_singleton_method(:standard_not_found_error) do |message:|
        raise ArgumentError, message
      end
      endpoint.define_singleton_method(:presenter) { |value| value }
    end
  end

  def action_model(method:, response:, kind:)
    entry = Struct.new(:http_method, :route_options, :params, :response) do
      def value(_parameters)
        response
      end
    end.new(method, {}, nil, response)
    config = Struct.new(:resource_actions, :collection_actions, :use_api_evaluation)
      .new(kind == :ResourceActions ? { consume: entry } : {},
        kind == :CollectionActions ? { consume: entry } : {}, false)
    Struct.new(:configuration) do
      def grape_api_resource_of(_context)
        configuration
      end
    end.new(config)
  end

  it "applies default_query_scope after query_scope" do
    endpoint = build_endpoint do
      model_klass GrapeResourcefulModel
      query_scope { |query| query + [:query_scope] }
      default_query_scope { |query| query + [:default_query_scope] }
    end

    expect(endpoint.send(:_query)).to eq(%i[base_scope query_scope default_query_scope])
  end

  it "reads default_query_scope from grape_api_resource configuration" do
    GrapeResourcefulModel.include Plugins::Models::Concerns::ApiResource
    GrapeResourcefulModel.grape_api_resource "test", default: true do
      default_query_scope { |query| query + [:configured_default_scope] }
    end

    endpoint = build_endpoint do
      model_klass GrapeResourcefulModel
      resource_context "test"
      query_scope { |query| query + [:query_scope] }
    end

    expect(endpoint.send(:_query)).to eq(%i[base_scope query_scope configured_default_scope])
  end

  %i[CollectionActions ResourceActions].each do |kind|
    it "re-evaluates a dynamic #{kind} model for every request" do
      route_class = action_route_for(kind)
      resolved = []
      route_class.public_send(kind == :CollectionActions ? :collection_actions_for :
        :resource_actions_for,
        proc { resolved << selected_model; selected_model }, "integration",
        action_name: :integration_action)
      post_model = action_model(method: "post", response: :posted, kind: kind)
      get_model = action_model(method: "get", response: :fetched, kind: kind)

      post_result = action_endpoint(model: post_model, method: "POST")
        .instance_exec(&route_class.handler)
      get_result = action_endpoint(model: get_model, method: "GET")
        .instance_exec(&route_class.handler)

      expect(post_result).to eq(:posted)
      expect(get_result).to eq(:fetched)
      expect(resolved).to eq([post_model, get_model])
    end

    it "registers PATCH for configured #{kind} actions" do
      route_class = action_route_for(kind)
      route_class.public_send(kind == :CollectionActions ? :collection_actions_for :
        :resource_actions_for, "GrapeResourcefulModel", "integration",
        action_name: :integration_action)

      expect(route_class.registered_methods).to include(:patch)
    end
  end
end
