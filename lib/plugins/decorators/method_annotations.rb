module Plugins
  module Decorators
    module MethodAnnotations
      def self.included(base)
        base.extend ClassMethods
        base.include Plugins::Models::Concerns::Options::InheritableClassAttribute
        base.inheritable_class_attribute :_method_annotations
        base._method_annotations ||= {}
        base.include(SmartSend)
      end

      module ClassMethods
        def annotate_method(method_name, annotations = {}, &block)
          define_method(method_name, &block) if block_given?
          _method_annotations[method_name.to_sym] ||= {}
          _method_annotations[method_name.to_sym].merge!(annotations)
        end

        def annotate_method!(method_name, annotations = {}, &block)
          clear_annotation_keys_except(method_name, *annotations.keys)
          annotate_method(method_name, annotations, &block)
        end


        def annotations_for(method_name)
          _method_annotations[method_name.to_sym] || {}
        end

        # def methods_annotated_with(key, value = nil)
        #   _method_annotations.select { |_, meta|
        #     meta.key?(key) && (value.nil? || meta[key] == value)
        #   }.keys
        # end

        def methods_annotated_with(key, value = nil)
          _method_annotations.select { |_, meta|
            next false unless meta.key?(key)

            if value.nil?
              true
            elsif meta[key].is_a?(Array)
              meta[key].include?(value)
            else
              meta[key] == value
            end
          }.keys
        end

        def method_annotated_with?(method_name, key, value = nil)
          meta = _method_annotations[method_name.to_sym]
          return false unless meta&.key?(key)

          if value.nil?
            true
          elsif meta[key].is_a?(Array)
            meta[key].include?(value)
          else
            meta[key] == value
          end
        end

        def clear_annotations_for(method_name)
          _method_annotations.delete(method_name.to_sym)
        end

        def clear_annotation_keys_for(method_name, *keys)
          meta = _method_annotations[method_name.to_sym]
          return unless meta
          keys.each { |key| meta.delete(key) }
        end

        def clear_annotation_keys_except(method_name, *keys)
          _method_annotations.each_key do |m|
            next if m.to_sym == method_name.to_sym
            clear_annotation_keys_for(m, *keys)
          end
        end

      end
    end
  end
end