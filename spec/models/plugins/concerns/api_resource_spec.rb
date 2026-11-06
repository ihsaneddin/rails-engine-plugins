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

          query_scope { |query| query + [:base_query_scope] }

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
      expect(app_cfg.get(:query_scope, [])).to eq([:base_query_scope])
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

    it "does not retain an inherited target context when cloning a subclass source context" do
      parent = builder.build_model do
        grape_api_resource "payment_core" do
          presenter "ParentSourcePresenter"
        end

        grape_api_resource "app", from: "payment_core" do
          presenter "ParentAppPresenter"
        end
      end

      child = Class.new(parent) do
        grape_api_resource "payment_core" do
          presenter "ChildSourcePresenter"
          query_scope { |query| query + [:child_query_scope] }
        end

        grape_api_resource "app", from: "payment_core"
      end

      app_cfg = child.grape_api_resource_of("app")

      expect(app_cfg.values[:presenter]).to eq("ChildSourcePresenter")
      expect(app_cfg.get(:query_scope, [])).to eq([:child_query_scope])
    end

    it "preserves a target composed earlier on the same class" do
      klass = builder.build_model do
        grape_api_resource "calendar" do
          presenter "SchedulePresenter"
          query_scope { |query| query + [:schedule_query_scope] }
          resource_params_attributes [:schedule_attributes]
          should_paginate false

          resource_actions do
            available_at do
              http_method "get"
            end
          end
        end

        grape_api_resource "branch", from: "calendar"

        grape_api_resource "app" do
          presenter "BranchPresenter"
        end

        grape_api_resource "branch", from: "app" do
          resource_identifier :slug
        end
      end

      branch_cfg = klass.grape_api_resource_of("branch")

      expect(branch_cfg.values[:presenter]).to eq("SchedulePresenter")
      expect(branch_cfg.get(:query_scope, [])).to eq([:schedule_query_scope])
      expect(branch_cfg.values[:resource_params_attributes]).to eq([:schedule_attributes])
      expect(branch_cfg.values[:should_paginate]).to eq(false)
      expect(branch_cfg.values[:resource_actions][:available_at].values[:http_method]).to eq("get")
      expect(branch_cfg.values[:resource_identifier]).to eq(:slug)
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
    it "clones a source context and applies overrides" do
      klass = builder.build_model do
        api_resource "payment_core", default: true do
          resource_identifier :uuid
          resource_finder_key :uuid
          query_scope { |query| query + [:base_query_scope] }
        end

        api_resource "app", from: "payment_core" do
          resource_finder_key :slug
        end
      end

      base_cfg = klass.api_resource_of("payment_core")
      app_cfg = klass.api_resource_of("app")

      expect(app_cfg.values[:resource_identifier]).to eq(:uuid)
      expect(app_cfg.values[:resource_finder_key]).to eq(:slug)
      expect(app_cfg.get(:query_scope, [])).to eq([:base_query_scope])
      expect(app_cfg).not_to equal(base_cfg)
      expect(klass.default_api_resource_config_context).to eq("payment_core")
    end

    it "does not retain an inherited target context when cloning a subclass source context" do
      parent = builder.build_model do
        api_resource "payment_core" do
          presenter "ParentSourcePresenter"
          resource_finder_key :uuid
        end

        api_resource "app", from: "payment_core" do
          presenter "ParentAppPresenter"
          resource_finder_key :slug
        end
      end

      child = Class.new(parent) do
        api_resource "payment_core" do
          presenter "ChildSourcePresenter"
          resource_finder_key :id
        end

        api_resource "app", from: "payment_core"
      end

      app_cfg = child.api_resource_of("app")

      expect(app_cfg.values[:presenter]).to eq("ChildSourcePresenter")
      expect(app_cfg.values[:resource_finder_key]).to eq(:id)
    end

    it "preserves a target composed earlier on the same class" do
      klass = builder.build_model do
        api_resource "calendar" do
          presenter "ScheduleSerializer"
          query_scope { |query| query + [:schedule_query_scope] }
          query_includes [:calendar]
        end

        api_resource "admin", from: "calendar"

        api_resource "app" do
          presenter "AdminSerializer"
          resource_finder_key :uuid
        end

        api_resource "admin", from: "app" do
          resource_identifier :slug
        end
      end

      admin_cfg = klass.api_resource_of("admin")

      expect(admin_cfg.values[:presenter]).to eq("ScheduleSerializer")
      expect(admin_cfg.get(:query_scope, [])).to eq([:schedule_query_scope])
      expect(admin_cfg.values[:query_includes]).to eq([:calendar])
      expect(admin_cfg.values[:resource_finder_key]).to eq(:uuid)
      expect(admin_cfg.values[:resource_identifier]).to eq(:slug)
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
