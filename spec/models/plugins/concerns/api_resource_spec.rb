require "spec_helper"
require "active_support/all"
require File.expand_path("../../../../lib/plugins/decorators", __dir__)

module Plugins
  def self.decorators
    Decorators
  end
end

require File.expand_path("../../../../lib/plugins/models/concerns/config", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/api_resource", __dir__)
require File.expand_path("../../../dummy/lib/dummy/plugins/models/concerns/api_resource_spec_support", __dir__)

RSpec.describe Plugins::Models::Concerns::ApiResource do
  let(:builder) { Dummy::Plugins::Models::Concerns::ApiResourceSpecSupport }

  describe ".grape_api_resource" do
    it "clones a source context and applies overrides" do
      klass = builder.build_model do
        grape_api_resource "payment_core", default: true do
          presenter "BasePresenter"
          resource_identifier :uuid

          resource_actions do
            approve do
              http_method "put"
            end
          end

          default_query_scope { |query| query + [:base_default_query_scope] }
        end

        grape_api_resource "app", from: "payment_core" do
          presenter "AppPresenter"
        end
      end

      base_cfg = klass.grape_api_resource_of("payment_core")
      app_cfg = klass.grape_api_resource_of("app")

      expect(app_cfg.values[:presenter]).to eq("AppPresenter")
      expect(app_cfg.values[:resource_identifier]).to eq(:uuid)
      expect(app_cfg.values[:resource_actions][:approve].values[:http_method]).to eq("put")
      expect(app_cfg.values[:resource_actions][:approve]).not_to equal(base_cfg.values[:resource_actions][:approve])
      expect(app_cfg.get(:default_query_scope, [])).to eq([:base_default_query_scope])
      expect(klass.default_grape_api_resource_config_context).to eq("payment_core")
    end

    it "allows the cloned context to become default explicitly" do
      klass = builder.build_model do
        grape_api_resource "payment_core", default: true do
          presenter "BasePresenter"
        end

        grape_api_resource "app", from: "payment_core", default: true do
          presenter "AppPresenter"
        end
      end

      expect(klass.default_grape_api_resource_config_context).to eq("app")
    end

    it "does not expose Rails controller fixed resource params" do
      klass = builder.build_model do
        grape_api_resource "base", default: true
      end

      expect(klass.grape_api_resource_of("base").exists?(:fixed_resource_params)).to eq(false)
    end

    it "raises for an unknown source context" do
      expect do
        builder.build_model do
          grape_api_resource "app", from: "missing" do
            presenter "AppPresenter"
          end
        end
      end.to raise_error(ArgumentError, /Unknown grape_api_resource context/)
    end
  end

  describe ".api_resource" do
    it "defaults fixed resource params to an empty hash" do
      klass = builder.build_model do
        api_resource "base", default: true
      end

      expect(klass.api_resource_of("base").fixed_resource_params).to eq({})
    end

    it "stores fixed resource params as a static hash" do
      klass = builder.build_model do
        api_resource "base", default: true do
          fixed_resource_params({ source: "trusted", kind: "managed" })
        end
      end

      expect(klass.api_resource_of("base").fixed_resource_params).to eq(
        source: "trusted",
        kind: "managed"
      )
    end

    it "inherits fixed resource params without sharing mutable state" do
      klass = builder.build_model do
        api_resource "base", default: true do
          fixed_resource_params({ source: "trusted" })
        end

        api_resource "derived", from: "base"
      end

      base_params = klass.api_resource_of("base").fixed_resource_params
      derived_params = klass.api_resource_of("derived").fixed_resource_params
      derived_params[:source] = "changed"

      expect(base_params).to eq(source: "trusted")
      expect(derived_params).to eq(source: "changed")
      expect(derived_params).not_to equal(base_params)
    end

    it "clones a source context and applies overrides" do
      klass = builder.build_model do
        api_resource "payment_core", default: true do
          resource_identifier :uuid
          resource_finder_key :uuid
        end

        api_resource "app", from: "payment_core" do
          resource_finder_key :slug
        end
      end

      base_cfg = klass.api_resource_of("payment_core")
      app_cfg = klass.api_resource_of("app")

      expect(app_cfg.values[:resource_identifier]).to eq(:uuid)
      expect(app_cfg.values[:resource_finder_key]).to eq(:slug)
      expect(app_cfg).not_to equal(base_cfg)
      expect(klass.default_api_resource_config_context).to eq("payment_core")
    end

    it "raises for an unknown source context" do
      expect do
        builder.build_model do
          api_resource "app", from: "missing" do
            resource_finder_key :slug
          end
        end
      end.to raise_error(ArgumentError, /Unknown api_resource context/)
    end
  end
end
