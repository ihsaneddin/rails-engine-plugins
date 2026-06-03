require "spec_helper"
require "active_record"
require "action_controller"
require "fileutils"
require "tmpdir"
require File.expand_path("../../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/paginated", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/responder", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/resourceful", __dir__)
require File.expand_path("../../../../lib/plugins/controllers/concerns/resourceful_action", __dir__)

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

  it "falls back to the controller folder when the model class is unresolved" do
    with_view_root("admin/resources/index.html.erb" => "base template") do |view_root|
      controller = build_controller do
        model_klass "Event"
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
end
