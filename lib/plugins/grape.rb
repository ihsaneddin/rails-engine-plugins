module Plugins
  module Grape
    autoload :Concerns, "plugins/grape/concerns"

    #extend ActiveSupport::Concern

    def self.included(base)
      _config = base.respond_to?(:grape_api_config) ? base.send(:grape_api_config) : Plugins.config.grape_api

      base.helpers do
        def _define_grape_api_config(config = null)
          if(config)
            unless self.class.respond_to?(:grape_api_config)
              self.class.class_eval do
                class_attribute :grape_api_config
                self.grape_api_config = config
              end
            end
          end
          self.class.grape_api_config
        end

        def grape_api_config
          self.class.grape_api_config
        end

      end

      base.before do
        _define_grape_api_config(_config)
      end

      base.include Plugins::Grape::Concerns::Paginated
      base.include Plugins::Grape::Concerns::Authenticate
      base.include Plugins::Grape::Concerns::Resourceful
      base.include Plugins::Grape::Concerns::Responder
      base.include Plugins::Configuration::Callbacks::Attacher
      base.callback_set = Plugins::Configuration::GrapeApi::ApiCallbackSet


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