require File.expand_path("../../../../../../lib/plugins/configuration/callbacks", __dir__)
require File.expand_path("../../../../../../lib/plugins/configuration/permissions", __dir__)
require File.expand_path("../../../../../../lib/plugins/configuration/events", __dir__)
require File.expand_path("../../../../../../lib/plugins/configuration/api", __dir__)
require File.expand_path("../../../../../../lib/plugins/configuration/grape_api", __dir__)
require File.expand_path("../../../../../../lib/plugins/configuration/bus", __dir__)
require File.expand_path("../../../../../../lib/plugins/configuration/core", __dir__)

module Dummy
  module PluginsConfigurationSupport
    class CallbackContext
      attr_accessor :value

      def mark(v)
        self.value = v
      end
    end

    class CallbackSetHost < ::Plugins::Configuration::Callbacks::CallbackSet
      CALLBACKS.concat(%w[index show])
    end

    class PermissionHost < ::Plugins::Configuration::Permissions::Permission; end
    class PermissionSetHost < ::Plugins::Configuration::Permissions::PermissionSet; end

    module CoreHost
      include ::Plugins::Configuration::Core
    end

    class ApiCallbackSetHost < ::Plugins::Configuration::Api::ApiCallbackSet; end

    module ApiCoreHost
      include ::Plugins::Configuration::Api::Core
    end

    class GrapeApiCallbackSetHost < ::Plugins::Configuration::GrapeApi::ApiCallbackSet; end

    module GrapeApiCoreHost
      include ::Plugins::Configuration::GrapeApi::Core
    end
  end
end
