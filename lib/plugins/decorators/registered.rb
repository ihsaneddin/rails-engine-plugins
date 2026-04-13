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

        def register_class(klass)
          new_set = (registered_classes || Set.new).dup
          new_set << klass
          self.registered_classes = new_set
        end

        alias << register_class

      end

    end
  end
end

