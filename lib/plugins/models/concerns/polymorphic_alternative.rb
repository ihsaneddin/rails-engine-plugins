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
              if send("#{att}")[new_assoc] == base_class.to_s
                return
              end
              send("#{att}")[new_assoc] = base_class.to_s
              belongs_to new_assoc.to_sym, foreign_key: rassoc.foreign_key, class_name: base_class.to_s, optional: true
              class_eval <<-CODE, __FILE__, __LINE__ + 1
                def #{assoc}_instance
                  relation = self.class.send('#{att}').find { |_key, val| val == '#{base_class.to_s}' }&.first
                  if respond_to?(relation)
                    send(relation)
                  else
                    send('#{assoc}')
                  end
                end
              CODE
            end
          end

        end

      end
    end
  end
end