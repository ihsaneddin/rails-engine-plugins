require "rails_helper"
require "plugins/models/field_options"

RSpec.describe Plugins::Models::FieldOptions do
  class FieldOptionsSpecChild < described_class
    attribute :name, type: :string
  end

  class FieldOptionsSpecConfig < described_class
    attribute :quantity, type: :integer
    attribute :enabled, type: :boolean

    default_value_for :quantity, 2
    default_value_for :enabled, false, allow_nil: false

    embeds_one :child, anonymous_class: FieldOptionsSpecChild

    validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  end

  it "casts attributes and applies defaults" do
    config = FieldOptionsSpecConfig.new(quantity: "3")

    expect(config.quantity).to eq(3)
    expect(config.enabled).to eq(false)
  end

  it "supports validations" do
    config = FieldOptionsSpecConfig.new(quantity: 0)

    expect(config).not_to be_valid
    expect(config.errors[:quantity]).to be_present
  end

  it "assigns nested attributes for embedded field options" do
    config = FieldOptionsSpecConfig.new(child_attributes: { name: "slot" })

    expect(config.child).to be_a(FieldOptionsSpecChild)
    expect(config.child.name).to eq("slot")
  end

  it "round-trips through the legacy YAML coder shape" do
    config = FieldOptionsSpecConfig.new(quantity: 5, child_attributes: { name: "slot" })

    loaded = FieldOptionsSpecConfig.load(FieldOptionsSpecConfig.dump(config))

    expect(loaded.quantity).to eq(5)
    expect(loaded.child.name).to eq("slot")
  end
end
