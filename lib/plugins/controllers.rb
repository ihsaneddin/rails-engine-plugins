module Plugins
  module Controllers
    autoload :Concerns, "plugins/controllers/concerns"

    extend ActiveSupport::Concern

    def self.use_plugins_controllers
      include Plugins::Controllers::Concerns::Authenticate
      include Plugins::Controllers::Concerns::Resourceful
      include Plugins::Configuration::Callbacks::Attacher

      self.callback_set = Plugins::Configuration::Api::ApiCallbackSet
    end

  end
end