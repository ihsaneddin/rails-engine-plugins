module Plugins
  module Decorators
    module Inheritables

      extend ActiveSupport::Concern

      included do
        include InheritableSingletonMethods
      end

      def self.singleton_methods
        InheritableSingletonMethods
      end

      def self.class_attributes
        InheritableClassAttribute
      end

      module InheritableClassAttribute
        extend ActiveSupport::Concern

        included do
          class_attribute :_inheritable_attributes, instance_accessor: false, default: []
        end

        class_methods do
          def inheritable_class_attribute(*attrs)
            attrs.each do |attr|
              # Prevent shared accessors
              unless self._inheritable_attributes.include?(attr)
                class_attribute attr, instance_accessor: false
                self._inheritable_attributes << attr
              end
            end
          end

          def inherited(subclass)
            super(subclass)
            subclass._inheritable_attributes = self._inheritable_attributes.dup
            _inheritable_attributes.each do |attr|
              value = send(attr)
              copied_value = deep_copy(value)
              subclass.send("#{attr}=", copied_value)
            end
          end

          private

          def deep_copy(value)
            case value
            when NilClass, Symbol, Numeric, TrueClass, FalseClass
              value
            when Hash
              copied = value.each_with_object({}) do |(k, v), acc|
                acc[k] = deep_copy(v)
              end
              copied.default_proc = value.default_proc if value.default_proc
              copied
            when Array
              value.map { |v| deep_copy(v) }
            when Set
              Set.new(value.map { |v| deep_copy(v) })
            else
              value.dup rescue value
            end
          end


        end

      end

      module InheritableSingletonMethods
        extend ActiveSupport::Concern

        included do
          include InheritableClassAttribute
          inheritable_class_attribute :_inheritable_singleton_methods
          self._inheritable_singleton_methods ||= []
        end

        class_methods do
          # Defines a singleton method and tracks it for inheritance.
          #
          # @param name [Symbol] the method name
          # @param visibility [:public, :private, :protected]
          def define_inheritable_singleton_method(name, visibility: :public, &block)
            raise ArgumentError, "Block required to define method #{name}" unless block_given?

            define_singleton_method(name, &block)

            singleton_class.send(visibility, name) if [:private, :protected].include?(visibility)

            self._inheritable_singleton_methods << name unless _inheritable_singleton_methods.include?(name)
          end

          def inherited(subclass)
            super(subclass)

            # Ensure the attribute is initialized on subclass

            _inheritable_singleton_methods.each do |method_name|
              method_obj = method(method_name)
              subclass.define_singleton_method(method_name, method_obj)
              # Preserve visibility from superclass
              if singleton_class.private_method_defined?(method_name)
                subclass.singleton_class.send(:private, method_name)
              elsif singleton_class.protected_method_defined?(method_name)
                subclass.singleton_class.send(:protected, method_name)
              end
            end
          end
        end
      end

    end
  end
end