module Plugins
  module Grape
    autoload :Concerns, "plugins/grape/concerns"
    autoload :Presenters, "plugins/grape/presenters"

    extend ActiveSupport::Concern

    class_methods do

      def use_plugins_grape(config=Plugins.config.grape_api)
        self.include ::Plugins::Decorators::Inheritables::InheritableClassAttribute
        self.inheritable_class_attribute :api_config
        self.api_config= config
        self.include(Endpoint)
      end

    end

    module Endpoint

      def self.included(base)
        base.helpers do
          def api_config
            #self.class_context.api_config
            class_context.api_config
          end

          def class_context &block
            block_given?? yield(env['api.endpoint'].options[:for].base) : env['api.endpoint'].options[:for].base
          end

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
          #subclass.define_context
        end

        # def define_context
        #   ctx = self
        #   before do
        #     _define_class_context(ctx)
        #   end
        # end

        def mount_with_context(*api_classes, &block)
          api_classes.each do |api_class|
            klass = duplicate(api_class, &block)
            #klass.class_exec(api_class, &block) if block_given?
            mount klass
          end
        end

        def _setup_ &block
          class_eval(&block) if block_given?
        end

        private

        def duplicate(api_class, &block)
          klass = Class.new(api_class)
          setup = api_class.instance_variable_get(:@setup)
          klass.instance_variable_set(:@setup, setup.dup) if setup
          klass.class_eval(&block) if block
          klass._setup_ do
            replay_setup_on(base_instance) if setup
          end
          klass
        end

      end


    end

  end
end