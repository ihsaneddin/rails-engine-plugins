module Plugins
  module Decorators
    module ConfigBuilder

      def self.config_class
        ::Plugins::Models::Concerns::Config
      end

      def self.config_builder(**opts)
        config_class.build(**opts)
      end

    end
  end
end

