module Plugins
  module Decorators
    module Hooks

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

        def after_class_defined(subclass, &block)
          tracer = TracePoint.new(:end) do |tp|
            next unless tp.self == subclass
            instance_exec(subclass, &block)
            tracer.disable
          end
          tracer.enable
        end

      end

    end
  end
end