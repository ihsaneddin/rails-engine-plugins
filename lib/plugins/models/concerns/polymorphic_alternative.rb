module Plugins
  module Models
    module Concerns
      module PolymorphicAlternative

        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods

          def define_alternative_polymorphic_parent_association(assoc:, new_assoc:, base_class:)
            rassoc = reflect_on_association(assoc.to_sym)
            if rassoc && rassoc.polymorphic? && rassoc.macro == :belongs_to
              att = "#{rassoc.name}_classes"
              class_attribute att unless respond_to?(att)
              send("#{att}=", {}) unless send(att).is_a?(Hash)
              if send("#{att}")[new_assoc] == base_class.to_s && reflect_on_association(new_assoc.to_sym)
                return
              end
              send("#{att}")[new_assoc] = base_class.to_s
              belongs_to new_assoc.to_sym, foreign_key: rassoc.foreign_key, class_name: base_class.to_s, optional: true
              define_method "#{assoc}_instance" do
                relation = self.class.send('#{att}').find { |_key, val| val == "#{base_class.to_s}" }&.first
                if respond_to?(relation)
                  send(relation)
                else
                  send("#{assoc}")
                end
              end
              # class_eval <<-CODE, __FILE__, __LINE__ + 1
              #   def #{assoc}_instance
              #     relation = self.class.send('#{att}').find { |_key, val| val == '#{base_class.to_s}' }&.first
              #     if respond_to?(relation)
              #       send(relation)
              #     else
              #       send('#{assoc}')
              #     end
              #   end
              # CODE
            end
          end

          def define_alternative_of_relation(klass, relation: :context, assoc_names: [])
            if assoc_names.blank?
              parts = klass.name.split("::").map(&:underscore)
              assoc_names = (0...parts.size).map do |i|
                parts[i..].join("_")
              end.map(&:to_sym)
            end
            assoc_names.reverse_each do |assoc_name|
              assoc_name = "#{relation}_of_#{assoc_name}".to_sym
              association = reflect_on_association(assoc_name)
              if association
                break if association.klass.name == klass.name
              else
                define_alternative_polymorphic_parent_association assoc: relation, new_assoc: assoc_name, base_class: klass.base_class
                break
              end
            end
          end

          def define_alternative_of_has_many_through_polymorphic_relation(klass, relation: nil, source: nil)
            parts = klass.name.split("::").map(&:underscore)
            assoc_names = (0...parts.size).map do |i|
              parts[i..].join("_")
            end.map(&:to_sym)
            assoc_names.reverse_each do |assoc_name|
              assoc_name = "#{assoc_name.pluralize}".to_sym
              unless reflect_on_association(assoc_name)
                klass.has_many assoc_name, through: relation, source: source, source_type: klass.base_class.name
                break
              end
            end
          end

        end

      end
    end
  end
end