module Plugins
  module Decorators
    module Traits

      def self.included mod
        if mod.is_a?(Module)
          mod.include Registered
          mod.mattr_accessor :registered_traits unless mod.respond_to?(:registered_traits)
          mod.registered_traits ||= Set.new
          mod.extend ClassMethods
          mod.singleton_class.prepend Module.new {
            def extended(trait_mod)
              super(trait_mod) if defined?(super)
              self.trait_registration(trait_mod)
            end
          }
        end
      end

      module ClassMethods

        def included base
          super(base) if defined?(super)
          if base.is_a?(Class)
            registered_traits.each do |trait|
              define_trait_flag_methods(base, trait)
              include_trait_class_methods(base, trait)
            end
          end
        end

        def register_trait mod
          registered_traits << mod
        end

        def trait_registration(trait_mod)
          register_trait(trait_mod)
          registered_classes.each do |klass|
            define_trait_flag_methods(klass, trait_mod)
            include_trait_class_methods(klass, trait_mod)
          end
        end

        def include_trait_class_methods(klass, trait)
          klass.extend trait.const_get(:ClassMethods) if trait.const_defined?(:ClassMethods)
        end

        def define_trait_flag_methods(klass, trait)
          trait_name = if trait.respond_to?(:trait_name)
                          trait.trait_name.to_s
                        else
                          trait.name.demodulize.underscore
                        end

          method_name = "#{trait_name}?"

          klass.include ::Plugins.decorators.inheritables.singleton_methods unless klass.include?(::Plugins.decorators.inheritables.singleton_methods)

          klass.define_inheritable_singleton_method(method_name) { false } unless klass.respond_to?(method_name)

          unless klass.method_defined?(method_name)
            klass.define_method(method_name) do
              self.class.send(method_name)
            end
          end
        end
      end

    end
  end
end

