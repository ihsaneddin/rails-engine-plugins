require "spec_helper"
require "active_support/all"
require "mutex_m"
require File.expand_path("../../../lib/plugins/configuration/permissions", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/configuration/support", __dir__)

RSpec.describe Plugins::Configuration::Permissions do
  describe Plugins::Configuration::Permissions::Permission do
    it "compares permissions by instance values" do
      first = described_class.new(:read, _namespace: [:admin], _priority: 1, _callable: true)
      second = described_class.new(:read, _namespace: [:admin], _priority: 1, _callable: true)

      expect(first).to eq(second)
    end
  end

  describe Plugins::Configuration::Permissions::ComputedPermissions do
    it "deduplicates and sorts permissions by priority" do
      low = Plugins::Configuration::Permissions::Permission.new(:read, _priority: 2)
      high = Plugins::Configuration::Permissions::Permission.new(:write, _priority: 1)

      computed = described_class.new([low, high, low])

      expect(computed.to_a).to eq([high, low])
    end
  end

  describe Plugins::Configuration::Permissions::PermissionSet do
    it "registers permissions from the mapper" do
      klass = Dummy::PluginsConfigurationSupport::PermissionSetHost
      klass.draw_permissions do
        permission :read, default: true
      end

      instance = klass.new(read: true)

      expect(instance.permitted_permission_names).to include("read")
      expect(klass.registered_permissions["read"]).to be_a(Plugins::Configuration::Permissions::Permission)
    end

    it "builds nested permission groups" do
      klass = Dummy::PluginsConfigurationSupport::PermissionSetHost
      custom_permission = Dummy::PluginsConfigurationSupport::PermissionHost
      klass.permission_class = custom_permission
      klass.draw_permissions do
        group :orders do
          permission :read, default: true
        end
      end

      nested = klass.nested_classes["orders"]

      expect(nested).not_to be_nil
      expect(nested.registered_permissions["read"]).to be_a(custom_permission)
    end
  end
end
