module Plugins
  module Decorators
    module Registered

      def self.included mod
        if mod.is_a?(Module)
          mod.mattr_accessor :registered_classes unless mod.respond_to?(:registered_classes)
          mod.registered_classes ||= Set.new
          mod.extend ClassMethods
        end
      end

      module ClassMethods
        def included base
          super(base) if defined?(super)
        end

        def register_class klass
          self.registered_classes << klass
        end

        def <<(klass)
          register_class klass
        end
      end

    end
  end
end

