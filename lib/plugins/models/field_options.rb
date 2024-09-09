
require 'active_entity'
require 'active_support/hash_with_indifferent_access'

module Plugins
  module Models
    class FieldOptions < ActiveEntity::Base

      module ActsAsDefaultValue
        extend ActiveSupport::Concern

        class NormalValueContainer
          def initialize(value)
            @value = value
          end

          def evaluate(_instance)
            if @value.duplicable?
              @value.dup
            else
              @value
            end
          end
        end

        class BlockValueContainer
          def initialize(block)
            @block = block
          end

          def evaluate(instance)
            if @block.arity.zero?
              @block.call
            else
              @block.call(instance)
            end
          end
        end

        included do
          after_initialize :set_default_values
        end

        def initialize(attributes = nil)
          @initialization_attributes = attributes.is_a?(Hash) ? attributes.stringify_keys : {}
          super
        end

        def set_default_values
          self.class._all_default_attribute_values.each do |attribute, container|
            next unless new_record? || self.class._all_default_attribute_values_not_allowing_nil.include?(attribute)
            attribute_blank =
              if self.class.attribute_types[attribute]&.type == :boolean
                send(attribute).nil? rescue nil
              else
                send(attribute).blank? rescue nil
              end
            next unless attribute_blank

            next if @initialization_attributes.is_a?(Hash) &&
                    (
                    @initialization_attributes.key?(attribute) ||
                      (
                      @initialization_attributes.key?("#{attribute}_attributes") &&
                        nested_attributes_options.stringify_keys[attribute]
                    )
                  ) &&
                    !self.class._all_default_attribute_values_not_allowing_nil.include?(attribute)

            send("#{attribute}=", container.evaluate(self))

            clear_attribute_changes [attribute] if has_attribute?(attribute)
          end
        end

        module ClassMethods
          def _default_attribute_values
            @default_attribute_values ||= {}
          end

          def _default_attribute_values_not_allowing_nil
            @default_attribute_values_not_allowing_nil ||= Set.new
          end

          def _all_default_attribute_values
            if superclass.respond_to?(:_default_attribute_values)
              superclass._all_default_attribute_values.merge(_default_attribute_values)
            else
              _default_attribute_values
            end
          end

          def _all_default_attribute_values_not_allowing_nil
            if superclass.respond_to?(:_default_attribute_values_not_allowing_nil)
              superclass._all_default_attribute_values_not_allowing_nil + _default_attribute_values_not_allowing_nil
            else
              _default_attribute_values_not_allowing_nil
            end
          end

          def default_value_for(attribute, value, **options)
            allow_nil = options.fetch(:allow_nil, true)

            container =
              if value.is_a? Proc
                BlockValueContainer.new(value)
              else
                NormalValueContainer.new(value)
              end

            _default_attribute_values[attribute.to_s] = container
            _default_attribute_values_not_allowing_nil << attribute.to_s unless allow_nil

            attribute
          end
        end
      end

      module EnumAttributeLocalizable
        extend ActiveSupport::Concern

        module ClassMethods
          def human_enum_value(attribute, value, options = {})
            parts     = attribute.to_s.split(".")
            attribute = parts.pop.pluralize
            attributes_scope = "#{i18n_scope}.attributes"

            if parts.any?
              namespace = parts.join("/")
              defaults = lookup_ancestors.map do |klass|
                :"#{attributes_scope}.#{klass.model_name.i18n_key}/#{namespace}.#{attribute}.#{value}"
              end
              defaults << :"#{attributes_scope}.#{namespace}.#{attribute}.#{value}"
            else
              defaults = lookup_ancestors.map do |klass|
                :"#{attributes_scope}.#{klass.model_name.i18n_key}.#{attribute}.#{value}"
              end
            end

            defaults << :"attributes.#{attribute}.#{value}"
            defaults << options.delete(:default) if options[:default]
            defaults << value.to_s.humanize

            options[:default] = defaults
            I18n.translate(defaults.shift, **options)
          end
        end
      end

      include ActsAsDefaultValue
      include EnumAttributeLocalizable

      class_attribute :keeping_old_serialization

      attr_accessor :raw_attributes

      #attribute :html_options, :json, default: {}

      def interpret_to(_model, _field_name, _accessibility, _options = {}); end

      def serializable_hash(options = {})
        options = (options || {}).reverse_merge include: self.class._embeds_reflections.keys
        super options
      end

      private

        def _assign_attribute(k, v)
          if self.class._embeds_reflections.key?(k)
            public_send("#{k}_attributes=", v)
          elsif respond_to?("#{k}=")
            public_send("#{k}=", v)
          end
        end

        class << self
          def _embeds_reflections
            _reflections.select { |_, v| v.is_a? ActiveEntity::Reflection::EmbeddedAssociationReflection }
          end

          def model_version
            1
          end

          def root_key_for_serialization
            "#{self}.#{model_version}"
          end

          def dump(obj)
            return YAML.dump({}) unless obj

            serializable_hash =
              if obj.respond_to?(:serializable_hash)
                obj.serializable_hash
              elsif obj.respond_to?(:to_hash)
                obj.to_hash
              else
                raise ArgumentError, "`obj` required can be cast to `Hash` -- #{obj.class}"
              end.stringify_keys

            data = { root_key_for_serialization => serializable_hash }
            data.reverse_merge! obj.raw_attributes if keeping_old_serialization

            YAML.dump(data)
          end

          def load(yaml_or_hash)
            case yaml_or_hash
            when Hash
              load_from_hash(yaml_or_hash)
            when String
              load_from_yaml(yaml_or_hash)
            else
              new
            end
          end

          #WHITELIST_CLASSES = [BigDecimal, Date, Time, Symbol].freeze
          WHITELIST_CLASSES = [Symbol, Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, ActiveSupport::HashWithIndifferentAccess, BigDecimal]

          def load_from_yaml(yaml)
            return new if yaml.blank?
            return new unless yaml.is_a?(String) && /^---/.match?(yaml)
            if YAML::VERSION.to_i < 4
              decoded = YAML.safe_load(yaml, WHITELIST_CLASSES)
            else
              decoded = YAML.safe_load(yaml, permitted_classes: WHITELIST_CLASSES)
            end
            #decoded = YAML.safe_load(yaml)
            return new unless decoded.is_a? Hash

            record = new decoded[root_key_for_serialization]
            record.raw_attributes = decoded.freeze
            record
          end

          def load_from_hash(hash)
            return new if hash.blank?

            record = new hash[root_key_for_serialization]
            record.raw_attributes = hash.freeze

            record
          end
        end
    end
  end
end
