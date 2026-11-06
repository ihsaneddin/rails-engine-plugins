require "spec_helper"
require "active_record"
require File.expand_path("../../../../lib/plugins/models/concerns/polymorphic_alternative", __dir__)

RSpec.describe Plugins::Models::Concerns::PolymorphicAlternative do
  before do
    stub_const("Admin", Module.new)
    stub_const("Admin::Context", Class.new(ActiveRecord::Base) do
      self.abstract_class = true
    end)
    stub_const("AuditEntry", Class.new(ActiveRecord::Base) do
      self.abstract_class = true
      belongs_to :context, polymorphic: true
      include Plugins::Models::Concerns::PolymorphicAlternative
    end)
  end

  it "defines alternative belongs_to associations with an absolute class name" do
    AuditEntry.define_alternative_polymorphic_parent_association(
      assoc: :context,
      new_assoc: :admin_context,
      base_class: Admin::Context
    )

    reflection = AuditEntry.reflect_on_association(:admin_context)

    expect(reflection.options[:class_name]).to eq("::Admin::Context")
    expect(AuditEntry.context_classes[:admin_context]).to eq("::Admin::Context")
  end

  it "uses the generated relation for a registered polymorphic type" do
    AuditEntry.define_alternative_polymorphic_parent_association(
      assoc: :context,
      new_assoc: :admin_context,
      base_class: Admin::Context
    )

    entry = AuditEntry.allocate
    context = Object.new
    alternative_context = Object.new
    entry.define_singleton_method(:context_type) { "Admin::Context" }
    entry.define_singleton_method(:context) { context }
    entry.define_singleton_method(:admin_context) { alternative_context }

    expect(entry.context_instance).to equal(alternative_context)
  end

  it "falls back to the polymorphic relation when the generated relation is empty" do
    AuditEntry.define_alternative_polymorphic_parent_association(
      assoc: :context,
      new_assoc: :admin_context,
      base_class: Admin::Context
    )

    entry = AuditEntry.allocate
    context = Object.new
    entry.define_singleton_method(:context_type) { "Admin::Context" }
    entry.define_singleton_method(:context) { context }
    entry.define_singleton_method(:admin_context) { nil }

    expect(entry.context_instance).to equal(context)
  end

  it "falls back to the polymorphic relation when the type has no generated relation" do
    AuditEntry.define_alternative_polymorphic_parent_association(
      assoc: :context,
      new_assoc: :admin_context,
      base_class: Admin::Context
    )

    entry = AuditEntry.allocate
    context = Object.new
    entry.define_singleton_method(:context_type) { "ExternalContext" }
    entry.define_singleton_method(:context) { context }

    expect(entry.context_instance).to equal(context)
  end
end
