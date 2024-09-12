module Plugins
  module Grape
    autoload :Concerns, "plugins/grape/concerns"

    extend ActiveSupport::Concern

    class_methods do
      def use_plugins_grape
        include Plugins::Grape::Concerns::Authenticate
        include Plugins::Grape::Concerns::Paginated
        include Plugins::Grape::Concerns::Resourceful
        # include Plugins::Grape::Callbacks::Attacher
        # self.callback_set = Plugins::Configuration::GrapeApi::ApiCallbackSet
      end
    end


  end
end