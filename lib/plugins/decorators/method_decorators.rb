module Plugins
  module Decorators
    module MethodDecorators
      def self.included(base)
        return if base.instance_variable_defined?(:@_method_decorators_loaded)

        base.extend ClassMethods
        base.include ::Plugins::Models::Concerns::Options::InheritableClassAttribute

        base.inheritable_class_attribute :_decorator_blocks
        base.inheritable_class_attribute :_decorated_methods
        base.inheritable_class_attribute :_already_wrapped_methods

        base._decorator_blocks ||= {}
        base._decorated_methods ||= Hash.new { |h, k| h[k] = {} }
        base._already_wrapped_methods ||= Set.new

        base.instance_variable_set(:@_method_decorators_loaded, true)
        base.include(SmartSend)
      end

      module ClassMethods
        def define_method_decorator(name, &block)
          raise ArgumentError, "Block is required!" unless block_given?

          _decorator_blocks[name.to_sym] = block

          define_singleton_method(name) do |method_name, **opts, &method_def|
            define_method(method_name, &method_def) if method_def
            decorate_method(method_name, with: name, **opts)
          end
        end

        def decorate_method(method_name, with:, **opts)
          _decorated_methods[with.to_sym][method_name.to_sym] = opts

          if method_defined?(method_name) || private_method_defined?(method_name) || self.new.respond_to?(method_name, true)
            apply_method_decorator(method_name, with: with.to_sym)
          end
        end

        def add_method_decorator(decorator_name, method_name, **opts)
          decorate_method(method_name, with: decorator_name.to_sym, **opts)
        end

        def method_added(method_name)
          @_decorator_lock ||= {}
          return if @_decorator_lock[method_name.to_sym]

          @_decorator_lock[method_name.to_sym] = true

          _decorated_methods.each do |decorator_name, methods|
            next unless methods.key?(method_name.to_sym)
            apply_method_decorator(method_name, with: decorator_name)
          end

          @_decorator_lock.delete(method_name.to_sym)

          super if defined?(super)
        end

        def inherited(subclass)
          super(subclass)

          # subclass._decorator_blocks = _decorator_blocks.deep_dup
          # subclass._decorated_methods = _decorated_methods.deep_dup
          # subclass._decorated_methods.default_proc = proc { |h, k| h[k] = {} }
          # subclass._already_wrapped_methods = _already_wrapped_methods.dup
        end

        private

        def apply_method_decorator(method_name, with:)
          method_name = method_name.to_sym
          wrap_key = [self.name, with.to_sym, method_name]

          return if _already_wrapped_methods.include?(wrap_key)

          decorator = _decorator_blocks[with]
          raise "Unknown method decorator: #{with}" unless decorator

          opts = _decorated_methods[with][method_name]

          original =
            if method_defined?(method_name) || private_method_defined?(method_name)
              instance_method(method_name)
            elsif self.new.respond_to?(method_name, true)
              method_obj = self.new.method(method_name)
              ->(*args, &block) { method_obj.call(*args, &block) }
            else
              raise NameError, "Method #{method_name} is not defined or accessible"
            end

          @_decorator_lock ||= {}
          @_decorator_lock[method_name] = true

          define_method(method_name) do |*args, &block|
            bound_original = original.is_a?(UnboundMethod) ? original.bind(self) : original
            instance_exec(method_name, bound_original, *args, block, **opts, &decorator)
          end

          _already_wrapped_methods.add(wrap_key)

          @_decorator_lock.delete(method_name)
        end
      end
    end
  end
end


# module Plugins
#   module Decorators
#     module MethodDecorators
#       def self.included(base)
#         return if base.instance_variable_defined?(:@_method_decorators_loaded)
#         base.extend ClassMethods
#         base.include ::Plugins::Models::Concerns::Options::InheritableClassAttribute
#         base.inheritable_class_attribute :_decorator_blocks
#         base.inheritable_class_attribute :_decorated_methods
#         base._decorator_blocks ||= {}
#         base._decorated_methods ||= Hash.new { |h, k| h[k] = {} }
#         base.instance_variable_set(:@_method_decorators_loaded, true)
#       end

#       module ClassMethods
#         def define_method_decorator(name, &block)
#           raise ArgumentError "Block is required!" unless block_given?
#           self._decorator_blocks[name.to_sym] = block
#           define_singleton_method(name) do |method_name, **opts, &method_def|
#             define_method(method_name, &method_def) if method_def
#             decorate_method(method_name, with: name, **opts)
#           end
#         end

#         def decorate_method(method_name, with:, **opts)
#           self._decorated_methods[with.to_sym] ||= {}
#           self._decorated_methods[with.to_sym][method_name.to_sym] = opts
#           apply_method_decorator(method_name, with: with.to_sym)
#         end

#         def add_method_decorator(decorator_name, method_name, **opts)
#           decorate_method(method_name, with: decorator_name.to_sym, **opts)
#         end

#         def method_added(method_name)
#           super if defined?(super)
#           return if @_decorator_lock
#           debugger if method_name.to_s == "complete!"
#           self._decorated_methods.each do |decorator_name, methods|
#             next unless methods.key?(method_name.to_sym)

#             @_decorator_lock = true
#             apply_method_decorator(method_name, with: decorator_name)
#             @_decorator_lock = false
#           end
#         end

#         def inherited(subclass)
#           super(subclass)
#           subclass._decorator_blocks = _decorator_blocks.deep_dup
#           subclass._decorated_methods = _decorated_methods.deep_dup
#           subclass._decorated_methods.default_proc = proc { |h, k| h[k] = {} }
#         end

#         private

#         def apply_method_decorator(method_name, with:)
#           decorator = self._decorator_blocks[with]
#           raise "Unknown method decorator: #{with}" unless decorator

#           opts = self._decorated_methods[with][method_name.to_sym]

#           original =
#             if method_defined?(method_name) || private_method_defined?(method_name)
#               instance_method(method_name)
#             elsif self.new.respond_to?(method_name, true) # check if it's dynamically defined
#               method_obj = self.new.method(method_name)
#               ->(*args, &block) { method_obj.call(*args, &block) }
#             else
#               raise NameError, "Method #{method_name} is not defined or accessible"
#             end

#           define_method(method_name) do |*args, &block|
#             bound_original = original.is_a?(UnboundMethod) ? original.bind(self) : original
#             instance_exec(method_name, bound_original, *args, block, **opts, &decorator)
#           end
#         end
#       end
#     end
#   end
# end