
module Plugins
  module Models
    module Concerns
      module CustomAttributes
        module Types
          class Base < ActiveModel::Type::Value

            def self.inherited(subclass)
              super(subclass)
              ::Plugins::Models::Concerns::CustomAttributes::Types.register_class(subclass)
              ActiveModel::Type.register(subclass.name.underscore.downcase.to_sym, subclass)
            end

            def self.define_custom_attributes_model_scopes(jsonb_attr, model_type, key, build_text_expr, build_exists_sql, method_name, array_root: false)

            end

            def self.define_custom_attributes_model_ransackers(jsonb_attr, model_type, key, build_text_expr, build_exists_sql, method_name, array_root: false)

            end

          end
        end
      end
    end
  end
end