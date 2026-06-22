require "spec_helper"
require "active_support/all"
require File.expand_path("../../../../lib/plugins/models/concerns/config", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/api_resource", __dir__)
require File.expand_path("../../../../lib/plugins/grape/concerns/resourceful", __dir__)

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
end
