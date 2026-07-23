require "spec_helper"
require "active_record"
require "action_controller"
require "fileutils"
require "tmpdir"
require File.expand_path("../../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../../lib/plugins/configuration/callbacks", __dir__)
require File.expand_path("../../../../lib/plugins/configuration/api", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/paginated", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/responder", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/resourceful", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/resourceful_action", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/config", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/api_resource", __dir__)

RSpec.describe Plugins::Controllers::Concerns::Resourceful do
  before do
    stub_const("Admin", Module.new)
    stub_const("Resource", Class.new(ActiveRecord::Base) do
      self.table_name = "resources"
    end)
    stub_const("Event", Class.new(Resource))
  end

  def build_controller(name = "Admin::ResourcesController", superclass: ActionController::Base, &block)
    controller_class = Class.new(superclass)
    stub_const(name, controller_class)
    controller_class.include Plugins::Controllers::Concerns::Resourceful
    controller_class.include Plugins::Controllers::Concerns::ResourcefulAction
    controller_class.class_eval(&block) if block
    controller_class.new
  end

  def with_view_root(files)
    Dir.mktmpdir do |root|
      files.each do |path, body|
        full_path = File.join(root, path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, body)
      end

      yield root
    end
  end

  def configure_resource(fixed_params: nil)
    Resource.include Plugins::Models::Concerns::ApiResource
    Resource.api_resource "default", default: true do
      resource_params_attributes [:name, :source, :kind, { metadata: [:origin] }]
      fixed_resource_params(fixed_params) unless fixed_params.nil?
    end
  end

  def request_with_body(parameters)
    ActionDispatch::TestRequest.create(
      "action_dispatch.request.request_parameters" => parameters
    )
  end

  def request_with_query(parameters)
    ActionDispatch::TestRequest.create(
      "action_dispatch.request.query_parameters" => parameters
    )
  end

  it "merges fixed resource params after permitting nested create body params" do
    fixed_params = { source: "trusted", kind: "managed" }
    configure_resource(fixed_params: fixed_params)
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(
      request_with_body(
        "resource" => {
          "name" => "Example",
          "source" => "request",
          "kind" => "request",
          "ignored" => "value"
        }
      )
    )
    allow(controller).to receive(:action_name).and_return("create")

    attributes = controller.send(:permitted_attributes)

    expect(attributes).to be_a(ActionController::Parameters)
    expect(attributes.to_h).to eq(
      "name" => "Example",
      "source" => "trusted",
      "kind" => "managed"
    )

    attributes[:source].replace("changed")
    expect(fixed_params).to eq(source: "trusted", kind: "managed")
    expect(Resource.api_resource_of("default")[:fixed_resource_params]).to eq(
      source: "trusted",
      kind: "managed"
    )
  end

  it "deeply isolates and permits nested trusted fixed resource params" do
    fixed_params = {
      source: "trusted",
      metadata: { origin: "trusted" }
    }
    configure_resource(fixed_params: fixed_params)
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(
      request_with_body(
        "resource" => {
          "source" => "request",
          "metadata" => { "origin" => "request" }
        }
      )
    )

    attributes = controller.send(:permitted_attributes)

    expect(attributes).to be_permitted
    expect(attributes[:metadata]).to be_permitted
    expect(attributes.to_h).to eq(
      "source" => "trusted",
      "metadata" => { "origin" => "trusted" }
    )

    attributes[:metadata][:origin].replace("changed")
    expect(fixed_params).to eq(
      source: "trusted",
      metadata: { origin: "trusted" }
    )
    expect(Resource.api_resource_of("default")[:fixed_resource_params]).to eq(
      source: "trusted",
      metadata: { origin: "trusted" }
    )
  end

  it "merges fixed resource params after permitting top-level update query params" do
    configure_resource(fixed_params: { source: "trusted", kind: "managed" })
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(
      request_with_query(
        "name" => "Example",
        "source" => "request",
        "kind" => "request",
        "ignored" => "value"
      )
    )
    allow(controller).to receive(:action_name).and_return("update")

    expect(controller.send(:permitted_attributes).to_h).to eq(
      "name" => "Example",
      "source" => "trusted",
      "kind" => "managed"
    )
  end

  it "preserves nested create permitted params when fixed resource params are absent" do
    configure_resource
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(
      request_with_body(
        "resource" => {
          "name" => "Example",
          "source" => "request",
          "ignored" => "value"
        }
      )
    )
    allow(controller).to receive(:action_name).and_return("create")

    expect(controller.send(:permitted_attributes).to_h).to eq(
      "name" => "Example",
      "source" => "request"
    )
  end

  it "preserves top-level update permitted params when fixed resource params are absent" do
    configure_resource
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(
      request_with_query(
        "name" => "Example",
        "source" => "request",
        "ignored" => "value"
      )
    )
    allow(controller).to receive(:action_name).and_return("update")

    expect(controller.send(:permitted_attributes).to_h).to eq(
      "name" => "Example",
      "source" => "request"
    )
  end

  it "rejects non-Hash fixed resource params with an explicit error" do
    configure_resource(fixed_params: [:source])
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(request_with_query({}))

    expect {
      controller.send(:permitted_attributes)
    }.to raise_error(ArgumentError, "fixed_resource_params must be a Hash")
  end

  it "rejects callable fixed resource params without evaluating them" do
    evaluated = false
    configure_resource(fixed_params: proc {
      evaluated = true
      { source: "evaluated" }
    })
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(request_with_query({}))

    expect {
      controller.send(:permitted_attributes)
    }.to raise_error(ArgumentError, "fixed_resource_params must be a Hash")
    expect(evaluated).to eq(false)
  end

  it "uses merged permitted attributes for resource action params" do
    configure_resource(fixed_params: { source: "trusted" })
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(
      request_with_body(
        "resource" => {
          "name" => "Example",
          "source" => "request",
          "ignored" => "value"
        }
      )
    )
    entry = Struct.new(:params).new(:permitted_attributes)

    expect(controller.send(:action_params, entry).to_h).to eq(
      "name" => "Example",
      "source" => "trusted"
    )
  end

  it "renders subclass templates from a nested controller/model folder by default" do
    with_view_root(
      "admin/resources/events/index.html.erb" => "event template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass Event
        use_model_view_path true
      end
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("event template")
    end
  end

  it "renders subclass templates by class name when the subclass overrides model_name" do
    Event.singleton_class.define_method(:model_name) { Resource.model_name }

    with_view_root(
      "admin/resources/events/index.html.erb" => "event template",
      "admin/resources/resources/index.html.erb" => "wrong model_name template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass Event
        use_model_view_path true
      end
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("event template")
    end
  end

  it "renders base model templates from the controller folder" do
    with_view_root(
      "admin/resources/resources/index.html.erb" => "invalid nested template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass Resource
        use_model_view_path true
      end
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("base template")
    end
  end

  it "renders from the controller folder when model-specific lookup is disabled" do
    with_view_root(
      "admin/resources/events/index.html.erb" => "event template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass Event
        use_model_view_path false
      end
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("base template")
    end
  end

  it "renders from a custom model view path" do
    with_view_root(
      "admin/resources/shared_events/index.html.erb" => "shared event template",
      "admin/resources/events/index.html.erb" => "event template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass Event
        model_view_path "shared_events"
      end
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("shared event template")
    end
  end

  it "prioritizes route default view base path without replacing controller model lookup" do
    with_view_root(
      "admin/locations/attachments/index.html.erb" => "location attachments template",
      "admin/resources/events/index.html.erb" => "event template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass Event
      end
      controller.set_request!(ActionDispatch::TestRequest.create("action_dispatch.request.path_parameters" => {
        view_base_path: "admin/locations/attachments"
      }))
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("location attachments template")
    end
  end

  it "falls back to controller model lookup when route default view base path has no template" do
    with_view_root(
      "admin/resources/events/index.html.erb" => "event template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass Event
      end
      controller.set_request!(ActionDispatch::TestRequest.create("action_dispatch.request.path_parameters" => {
        view_base_path: "admin/locations/attachments"
      }))
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("event template")
    end
  end

  it "prioritizes route default view base path when model view path is blank" do
    with_view_root(
      "admin/locations/attachments/index.html.erb" => "location attachments template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass Resource
      end
      controller.set_request!(ActionDispatch::TestRequest.create("action_dispatch.request.path_parameters" => {
        view_base_path: "admin/locations/attachments"
      }))
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("location attachments template")
    end
  end

  it "falls back to the controller folder when the model class is blank" do
    with_view_root("admin/resources/index.html.erb" => "base template") do |view_root|
      controller = build_controller do
        model_klass { nil }
        use_model_view_path true
      end
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("base template")
    end
  end

  it "renders subclass templates when the model class is a class name string" do
    with_view_root(
      "admin/resources/events/index.html.erb" => "event template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass "Event"
        use_model_view_path true
      end
      controller.class.view_paths = [view_root]

      expect(Event).to be < Resource
      expect(controller.render_to_string(:index)).to eq("event template")
    end
  end

  it "renders subclass templates when the model class block returns a class name string" do
    with_view_root(
      "admin/resources/events/index.html.erb" => "event template",
      "admin/resources/index.html.erb" => "base template"
    ) do |view_root|
      controller = build_controller do
        model_klass { "Event" }
        use_model_view_path true
      end
      controller.class.view_paths = [view_root]

      expect(Event).to be < Resource
      expect(controller.render_to_string(:index)).to eq("event template")
    end
  end

  it "falls back to the controller folder when the model class string is unresolved" do
    with_view_root("admin/resources/index.html.erb" => "base template") do |view_root|
      controller = build_controller do
        model_klass "MissingEvent"
        use_model_view_path true
      end
      controller.class.view_paths = [view_root]

      expect(controller.render_to_string(:index)).to eq("base template")
    end
  end

  it "stores resourceful params as the current class config hash" do
    controller = build_controller do
      model_klass Event
    end

    controller.class.resourceful_params

    expect(controller.class.resourceful_params_).to include(:model_klass)
    expect(controller.class.resourceful_params_).not_to include("Admin::ResourcesController")
  end

  it "inherits resourceful params without mutating the parent config" do
    parent = build_controller("Admin::BaseResourcesController") do
      model_klass Resource
      resources_actions [:index]
    end
    child = build_controller("Admin::ChildResourcesController", superclass: parent.class) do
      model_klass Event
      resources_actions [:index, :archived]
    end

    expect(parent.class.resourceful_params(:model_klass)).to eq(Resource)
    expect(parent.class.resourceful_params(:resources_actions)).to eq([:index])
    expect(child.class.resourceful_params(:model_klass)).to eq(Event)
    expect(child.class.resourceful_params(:resources_actions)).to eq([:index, :archived])
  end

  it "inherits resourceful action overrides from the parent" do
    parent = build_controller("Admin::ActionBaseResourcesController") do
      resourceful_for :show, model_klass: Resource
    end
    child = build_controller("Admin::ActionChildResourcesController", superclass: parent.class)

    expect(child.class.resourceful_overrides[:show][:model_klass]).to eq(Resource)
  end

  it "does not mutate parent resourceful action overrides from a child" do
    parent = build_controller("Admin::ActionParentResourcesController") do
      resourceful_for :show, model_klass: Resource
    end
    child = build_controller("Admin::ActionOverrideResourcesController", superclass: parent.class) do
      resourceful_for :show, model_klass: Event
    end

    expect(parent.class.resourceful_overrides[:show][:model_klass]).to eq(Resource)
    expect(child.class.resourceful_overrides[:show][:model_klass]).to eq(Event)
  end

  it "applies default query scope to the resolved query scope result" do
    controller = build_controller do
      model_klass "Resource"
      query_scope { |_model| [:query_scope] }
      default_query_scope { |query| query + [:default_query_scope] }
    end
    controller.set_request!(ActionDispatch::TestRequest.create)

    expect(controller.send(:_query)).to eq(%i[query_scope default_query_scope])
  end

  it "resolves resourceful redirect paths from route defaults with the current record" do
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(ActionDispatch::TestRequest.create("action_dispatch.request.path_parameters" => {
      resourceful_redirects: {
        update: {
          to: "edit",
          id: "record"
        }
      }
    }))
    controller.replace_resource(instance_double("Resource", to_param: "42"))
    allow(controller).to receive(:url_for) do |options|
      "/resources/#{options.fetch(:id)}/#{options.fetch(:action)}"
    end

    expect(controller.send(:resourceful_redirect_path, :update)).to eq("/resources/42/edit")
  end

  it "falls back to controller resourceful redirect config when no route default is present" do
    controller = build_controller do
      model_klass "Resource"
      resourceful_redirects update: :edit
    end
    controller.set_request!(ActionDispatch::TestRequest.create)
    controller.replace_resource(instance_double("Resource", to_param: "43"))
    allow(controller).to receive(:url_for) do |options|
      "/resources/#{options.fetch(:id)}/#{options.fetch(:action)}"
    end

    expect(controller.send(:resourceful_redirect_path, :update)).to eq("/resources/43/edit")
  end

  it "returns explicit absolute paths from route redirect defaults" do
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(ActionDispatch::TestRequest.create("action_dispatch.request.path_parameters" => {
      resourceful_redirects: {
        create: "/admin/resources"
      }
    }))

    expect(controller.send(:resourceful_redirect_path, :create)).to eq("/admin/resources")
  end

  it "returns fallback when no resourceful redirect is configured" do
    controller = build_controller do
      model_klass "Resource"
    end
    controller.set_request!(ActionDispatch::TestRequest.create)

    expect(controller.send(:resourceful_redirect_path, :create, fallback: "/fallback")).to eq("/fallback")
  end

  it "uses configured total page header when calculating the last page flag" do
    pagination_config = Plugins::Configuration::Api::Pagination::Configuration.new
    pagination_config.page = "Page"
    pagination_config.per_page = "Limit"
    pagination_config.total = "Total-Count"
    pagination_config.total_page = "Page-Count"
    pagination_config.last_page = "Is-Last-Page"

    pagination = Module.new
    pagination.define_singleton_method(:config) { pagination_config }

    api_config = Module.new
    api_config.define_singleton_method(:pagination) { pagination }

    controller = build_controller do
      define_method(:api_config) { api_config }
    end
    controller.set_response!(ActionDispatch::TestResponse.new)
    controller.headers["Limit"] = "25"
    controller.headers["Page"] = "4"
    controller.headers["Total-Count"] = "100"

    expect(controller.send(:pagination_info)).to include(
      "Page-Count" => 4,
      "Is-Last-Page" => true
    )
  end
end
