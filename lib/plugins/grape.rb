module Plugins
  module Grape
    autoload :Concerns, "plugins/grape/concerns"

    #extend ActiveSupport::Concern

    def self.included(base)
      base.include Plugins::Grape::Concerns::Paginated
      base.include Plugins::Grape::Concerns::Authenticate
      base.include Plugins::Grape::Concerns::Resourceful
      base.include Plugins::Grape::Concerns::Responder
    end

    # class_methods do
    #   def use_plugins_grape
    #     ::Grape::API::Instance.include Plugins::Grape::Concerns::Authenticate
    #     ::Grape::API::Instance.include Plugins::Grape::Concerns::Paginated
    #     ::Grape::API::Instance.include Plugins::Grape::Concerns::Resourceful
    #     # include Plugins::Grape::Callbacks::Attacher
    #     # self.callback_set = Plugins::Configuration::GrapeApi::ApiCallbackSet
    #   end
    # end


  end
end