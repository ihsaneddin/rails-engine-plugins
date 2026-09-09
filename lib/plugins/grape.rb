module Plugins
  module Grape
    autoload :Concerns, "plugins/grape/concerns"
    autoload :Presenters, "plugins/grape/presenters"

    ADD_SETUP_GUARD_GRAPE_VERSION = "1.6.2".freeze

    # Compatibility shim for Grape 1.6.2: its API method proxy records Ruby's
    # method-added lifecycle notifications in Grape's setup list. Plugins must
    # copy and replay that list for every fresh `.draw`/mounted API class, so
    # replaying these non-DSL notifications multiplies no-op work during boot.
    # Filter only the two proven lifecycle hooks and delegate every real Grape
    # setup unchanged. Remove this shim only after an upgrade is verified not to
    # record them and the application's route and Resourceful contracts pass.
    module AddSetupGuard
      IGNORED_SETUP_METHODS = %i[method_added singleton_method_added].freeze

      def add_setup(method, *args, &block)
        return if IGNORED_SETUP_METHODS.include?(method)

        super
      end
    end

    def self.install_add_setup_guard(api_class, grape_version: ::Grape::VERSION)
      return api_class unless grape_version.to_s == ADD_SETUP_GUARD_GRAPE_VERSION
      return api_class if api_class.singleton_class < AddSetupGuard

      api_class.singleton_class.prepend(AddSetupGuard)
      api_class
    end

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
          klass.helpers do
            def api_config
              #self.class_context.api_config
              class_context.api_config
            end

            def class_context &block
              block_given?? yield(env['api.endpoint'].options[:for].base) : env['api.endpoint'].options[:for].base
            end

          end
          klass._setup_ do
            replay_setup_on(base_instance) if setup
          end
          klass
        end

      end


    end

  end
end
