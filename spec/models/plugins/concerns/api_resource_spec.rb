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

  shared_examples "deferred resource configuration propagation" do |resource_method|
    it "propagates a late parent context without overriding subclass-local composition" do
      parent = builder.build_model
      child = Class.new(parent)
      sibling = Class.new(parent)

      child.public_send(resource_method, "app") do
        presenter "ChildPresenter"
      end
      child.public_send(resource_method, "admin", from: "app", default: false) do
        collection_actions do
          child_action do
            http_method "post"
          end
        end
      end
      sibling.public_send(resource_method, "admin") do
        collection_actions do
          sibling_action do
            http_method "patch"
          end
        end
      end

      parent.public_send(resource_method, "admin", default: true) do
        presenter "ParentPresenter"
        resource_identifier :uuid
        query_includes [:parent_include]

        collection_actions do
          inherited_action do
            http_method "get"
          end
        end
      end

      parent_config = parent.public_send("#{resource_method}_of", "admin")
      child_config = child.public_send("#{resource_method}_of", "admin")
      sibling_config = sibling.public_send("#{resource_method}_of", "admin")

      expect(parent_config.values[:collection_actions].keys).to eq([:inherited_action])
      expect(child_config.values[:collection_actions].keys).to eq(%i[inherited_action child_action])
      expect(sibling_config.values[:collection_actions].keys).to eq(%i[inherited_action sibling_action])

      expect(child_config.values[:presenter]).to eq("ChildPresenter")
      expect(sibling_config.values[:presenter]).to eq("ParentPresenter")
      expect(child_config.values[:resource_identifier]).to eq(:uuid)
      expect(sibling_config.values[:query_includes]).to eq([:parent_include])
      expect(child_config.values[:default]).to eq(false)
      expect(sibling_config.values[:default]).to eq(true)

      expect(child_config).not_to equal(parent_config)
      expect(sibling_config).not_to equal(parent_config)
      expect(child_config.values[:collection_actions]).not_to equal(parent_config.values[:collection_actions])
      expect(sibling_config.values[:collection_actions]).not_to equal(parent_config.values[:collection_actions])
      expect(child_config.values[:collection_actions][:inherited_action])
        .not_to equal(parent_config.values[:collection_actions][:inherited_action])

      parent.public_send(resource_method, "admin") do
        presenter "UpdatedParentPresenter"
        resource_identifier :slug
        query_includes [:updated_parent_include]

        collection_actions do
          second_inherited_action do
            http_method "put"
          end
        end
      end

      parent_config = parent.public_send("#{resource_method}_of", "admin")
      child_config = child.public_send("#{resource_method}_of", "admin")
      sibling_config = sibling.public_send("#{resource_method}_of", "admin")

      expect(child_config.values[:presenter]).to eq("ChildPresenter")
      expect(sibling_config.values[:presenter]).to eq("UpdatedParentPresenter")
      expect(child_config.values[:resource_identifier]).to eq(:slug)
      expect(sibling_config.values[:query_includes]).to eq([:updated_parent_include])
      expect(child_config.values[:default]).to eq(false)
      expect(child_config.values[:collection_actions].keys)
        .to eq(%i[inherited_action second_inherited_action child_action])
      expect(sibling_config.values[:collection_actions].keys)
        .to eq(%i[inherited_action second_inherited_action sibling_action])

      child_config.values[:collection_actions][:inherited_action].set(:http_method, "delete")
      expect(parent_config.values[:collection_actions][:inherited_action].values[:http_method]).to eq("get")
      expect(sibling_config.values[:collection_actions][:inherited_action].values[:http_method]).to eq("get")
    end

    it "retains inherited target actions when a subclass later composes from another context" do
      parent = builder.build_model do
        public_send(resource_method, "admin") do
          presenter "ParentPresenter"

          collection_actions do
            inherited_action do
              http_method "get"
            end
          end
        end
      end
      child = Class.new(parent) do
        public_send(resource_method, "app") do
          presenter "ChildPresenter"
        end

        public_send(resource_method, "admin", from: "app") do
          collection_actions do
            child_action do
              http_method "post"
            end
          end
        end
      end

      parent_config = parent.public_send("#{resource_method}_of", "admin")
      child_config = child.public_send("#{resource_method}_of", "admin")

      expect(parent_config.values[:collection_actions].keys).to eq([:inherited_action])
      expect(child_config.values[:collection_actions].keys).to eq(%i[inherited_action child_action])
      expect(child_config.values[:presenter]).to eq("ChildPresenter")
      expect(child_config.values[:collection_actions]).not_to equal(parent_config.values[:collection_actions])
      expect(child_config.values[:collection_actions][:inherited_action])
        .not_to equal(parent_config.values[:collection_actions][:inherited_action])
    end
  end

  describe ".grape_api_resource" do
    include_examples "deferred resource configuration propagation", :grape_api_resource

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
    include_examples "deferred resource configuration propagation", :api_resource

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

    it "isolates a deferred subclass context from its ancestor and siblings" do
      parent = builder.build_model
      child = Class.new(parent)
      sibling = Class.new(parent)

      parent.api_resource "admin" do
        collection_actions do
          inherited_action do
            http_method "get"
          end
        end
      end

      child.api_resource "admin" do
        collection_actions do
          child_action do
            http_method "post"
          end
        end
      end

      parent_actions = parent.api_resource_of("admin").values[:collection_actions]
      child_actions = child.api_resource_of("admin").values[:collection_actions]
      sibling_actions = sibling.api_resource_of("admin").values[:collection_actions]

      expect(parent_actions.keys).to eq([:inherited_action])
      expect(sibling_actions.keys).to eq([:inherited_action])
      expect(child_actions.keys).to eq(%i[inherited_action child_action])
      expect(child_actions).not_to equal(parent_actions)
      expect(child_actions).not_to equal(sibling_actions)
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
