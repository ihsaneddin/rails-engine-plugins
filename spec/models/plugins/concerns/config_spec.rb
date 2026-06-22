require "spec_helper"
require "active_support/all"
require File.expand_path("../../../../lib/plugins/models/concerns/config", __dir__)

RSpec.describe Plugins::Models::Concerns::Config do
  describe "#merge" do
    it "overrides top-level keys from another config" do
      base = described_class.build(name: "base", code: "A")
      override = described_class.build(code: "B")

      merged = base.merge(override)

      expect(merged.values[:name]).to eq("base")
      expect(merged.values[:code]).to eq("B")
      expect(base.values[:code]).to eq("A")
    end
  end

  describe "#deep_merge" do
    it "preserves nested config values that are not overridden" do
      base = described_class.build(
        nested: described_class.build(primary: "alpha", secondary: "beta"),
        presenter: "BasePresenter"
      )
      override = described_class.build(
        nested: described_class.build(secondary: "gamma"),
        presenter: "AppPresenter"
      )

      merged = base.deep_merge(override)

      expect(merged.values[:presenter]).to eq("AppPresenter")
      expect(merged.values[:nested].values[:primary]).to eq("alpha")
      expect(merged.values[:nested].values[:secondary]).to eq("gamma")
      expect(merged.values[:nested]).not_to equal(base.values[:nested])
    end
  end

  describe Plugins::Models::Concerns::Config::Collection do
    describe "dynamic entries" do
      it "duplicates nested config templates for each dynamic entry" do
        collection = described_class.new(
          values: {
            actions: described_class.new(values: { params: described_class.new(values: {}) })
          }
        )

        collection.setup do
          assignment_overlap do
            actions do
              reassign_staff do
                params do
                  reassignments
                end
              end
            end
          end

          schedule_exception_overlap do
            actions do
              reassign_staff do
                params do
                  blocked_ranges
                end
              end
            end
          end
        end

        assignment_params = collection[:assignment_overlap].actions[:reassign_staff].params
        schedule_params = collection[:schedule_exception_overlap].actions[:reassign_staff].params

        expect(assignment_params.keys).to eq([:reassignments])
        expect(schedule_params.keys).to eq([:blocked_ranges])
        expect(assignment_params).not_to equal(schedule_params)
      end
    end

    describe "#deep_merge" do
      it "preserves source entries, overrides matching entries, and appends new entries" do
        base = described_class.new(values: {})
        base.setup do
          approve do
            http_method "put"
            params [:state]
          end
        end

        override = described_class.new(values: {})
        override.setup do
          approve do
            params [:status]
          end

          archive do
            http_method "delete"
          end
        end

        merged = base.deep_merge(override)

        expect(merged[:approve].values[:http_method]).to eq("put")
        expect(merged[:approve].values[:params]).to eq([:status])
        expect(merged[:archive].values[:http_method]).to eq("delete")
        expect(merged.order).to eq([:approve, :archive])
        expect(merged[:approve]).not_to equal(base[:approve])
      end
    end
  end
end
