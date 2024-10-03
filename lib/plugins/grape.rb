module Plugins
  module Grape
    autoload :Concerns, "plugins/grape/concerns"

    extend ActiveSupport::Concern

    class_methods do

      def use_plugins_grape(config=Plugins.config.grape_api)
        self.class_attribute :api_config
        self.api_config= config
        self.include(Endpoint)
      end

    end

    module Endpoint

      def self.included(base)
        base.helpers do
          def _define_api_config(config = Plugins.config.grape_api)
            if(config)
              unless self.class.respond_to?(:api_config)
                self.class.class_eval do
                  class_attribute :api_config
                  self.api_config = config
                end
              end
            end
            self.class.api_config
          end

          def api_config
            self.class.api_config
          end

          def _define_class_context(context)
            unless self.class.respond_to?(:context)
              self.class.class_eval do
                class_attribute :context
              end
            end
            self.class.context = context
            self.class.context
          end

          def class_context &block
            if self.class.respond_to?(:context) && self.class.context
              block_given?? yield(self.class.context) : self.class.context
            end
          end

        end
        cfg = base.api_config
        base.before do
          _define_api_config(cfg)
        end
        base.extend ClassMethods
        base.include Plugins::Grape::Concerns::Paginated
        base.include Plugins::Grape::Concerns::Authenticate
        base.include Plugins::Grape::Concerns::Resourceful
        base.include Plugins::Grape::Concerns::Responder
        base.include Plugins::Configuration::Callbacks::Attacher
        base.callback_set = Plugins::Configuration::GrapeApi::ApiCallbackSet

      end

      module ClassMethods
        def inherited(subclass)
          if defined?(super)
            super
          end
          subclass.define_context
        end

        def define_context
          ctx = self
          before do
            _define_class_context(ctx)
          end
        end
      end


    end

  end
end