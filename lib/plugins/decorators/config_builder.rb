module Plugins
  module Decorators
    module ConfigBuilder

      def config_class
        ::Plugins::Models::Concerns::Config
      end

      def collection_config_class
        ::Plugins::Models::Concerns::Config::Collection
      end

      def config_builder(**opts)
        config_class.build(**opts)
      end

      def plugins_config
        config_class
      end

      def plugins_collection_config
        collection_config_class
      end

    end
  end
end

