module Plugins
  module Decorators
    module ConfigBuilder

      def config_class
        ::Plugins::Models::Concerns::Config
      end

      def config_builder(**opts)
        config_class.build(**opts)
      end

    end
  end
end

