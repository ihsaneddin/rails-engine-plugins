module Plugins
  module Decorators
    module MethodAnnotations
      def self.included(base)
        base.extend ClassMethods
        base.include Plugins::Models::Concerns::Options::InheritableClassAttribute
        base.inheritable_class_attribute :_method_annotations
        base._method_annotations ||= {}
      end

      module ClassMethods
        def annotate_method(method_name, annotations = {}, &block)
          define_method(method_name, &block) if block_given?
          _method_annotations[method_name.to_sym] ||= {}
          _method_annotations[method_name.to_sym].merge!(annotations)
        end

        def annotations_for(method_name)
          _method_annotations[method_name.to_sym] || {}
        end

        def methods_annotated_with(key, value = nil)
          _method_annotations.select { |_, meta|
            meta.key?(key) && (value.nil? || meta[key] == value)
          }.keys
        end

        def clear_annotations_for(method_name)
          _method_annotations.delete(method_name.to_sym)
        end
      end
    end
    # module MethodMetadata
    #   def self.included(base)
    #     base.extend(ClassMethods)
    #     base.include Plugins::Models::Concerns::Options::InheritableClassAttribute
    #     base.inheritable_class_attribute :method_metadata_map
    #     base.method_metadata_map ||= {}
    #   end

    #   module ClassMethods
    #     def decorate_method(method_name, metadata = {}, &block)
    #       define_method(method_name, &block) if block_given?
    #       method_metadata_map[method_name.to_sym] ||= {}
    #       method_metadata_map[method_name.to_sym].merge!(metadata)
    #     end

    #     def decorated_metadata_for(method_name)
    #       method_metadata_map[method_name.to_sym] || {}
    #     end

    #     def decorated_methods_with(key, value = nil)
    #       method_metadata_map.select { |_, meta|
    #         meta.key?(key) && (value.nil? || meta[key] == value)
    #       }.keys
    #     end

    #     def clear_decorated_metadata_for(method_name)
    #       method_metadata_map.delete(method_name.to_sym)
    #     end
    #   end
    # end
  end
end