module Plugins
  module Controllers
    autoload :Concerns, "plugins/controllers/concerns"

    extend ActiveSupport::Concern

    class_methods do
      def use_plugins_controllers(config = Plugins::Configuration::Api)

        class_attribute :api_config
        self.api_config= config

        include Plugins::Controllers::Concerns::Authenticate
        include Plugins::Controllers::Concerns::Resourceful
        include Plugins::Configuration::Callbacks::Attacher

        self.callback_set = Plugins::Configuration::Api::ApiCallbackSet
      end
    end

  end
end