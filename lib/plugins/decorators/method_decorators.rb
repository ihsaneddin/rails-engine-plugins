module Plugins
  module Decorators
    module MethodDecorators
      def self.included(base)
        base.extend ClassMethods
        base.include InheritableClassAttribute

        base.inheritable_class_attribute :_decorator_blocks
        base.inheritable_class_attribute :_decorated_methods

        base._decorator_blocks ||= {}
        base._decorated_methods ||= Hash.new { |h, k| h[k] = {} }
      end

      module ClassMethods
        def define_method_decorator(name, &block)
          _decorator_blocks[name.to_sym] = block

          define_singleton_method(name) do |method_name, **opts, &method_def|
            define_method(method_name, &method_def) if method_def
            decorate_method(method_name, with: name, **opts)
          end
        end

        def decorate_method(method_name, with:, **opts)
          _decorated_methods[with.to_sym][method_name.to_sym] = opts
          apply_method_decorator(method_name, with: with.to_sym)
        end

        def add_method_decorator(decorator_name, method_name, **opts)
          decorate_method(method_name, with: decorator_name.to_sym, **opts)
        end

        def method_added(method_name)
          super if defined?(super)
          return if @_decorator_lock

          _decorated_methods.each do |decorator_name, methods|
            next unless methods.key?(method_name.to_sym)

            @_decorator_lock = true
            apply_method_decorator(method_name, with: decorator_name)
            @_decorator_lock = false
          end
        end

        private

        def apply_method_decorator(method_name, with:)
          original = instance_method(method_name)
          decorator = _decorator_blocks[with]
          opts = _decorated_methods[with][method_name.to_sym]

          define_method(method_name) do |*args, &block|
            instance_exec(method_name, original.bind(self), *args, block, **opts, &decorator)
          end
        end
      end
    end
  end
end