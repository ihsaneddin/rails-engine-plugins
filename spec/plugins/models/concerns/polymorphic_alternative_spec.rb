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
end
