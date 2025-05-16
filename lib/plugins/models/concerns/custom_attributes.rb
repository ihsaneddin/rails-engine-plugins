module Plugins
  module Models
    module Concerns
      module CustomAttributes
        extend ActiveSupport::Concern

        class_methods do
          def custom_attributes_definition(attribute_name, model_type)
            check_jsonb_compatibility!
            attribute attribute_name, model_type

            define_store_model_ransackers(attribute_name, model_type.model_class)
          end

          def check_jsonb_compatibility!
            adapter = ActiveRecord::Base.connection.adapter_name.downcase
            unless adapter.include?("postgresql")
              raise Plugins::ErrorsUnsupportedAdapterError,
                    "JSONB querying is only supported on PostgreSQL. Current adapter: #{adapter}"
            end
          end

          def define_store_model_ransackers(jsonb_attr, model_class, prefix = nil)
            model_class.attribute_types.each do |key, type|
              full_key = [prefix, key].compact.join("_")

              case type
              when ActiveModel::Type::String
                ransacker full_key do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')")
                end
              when ActiveModel::Type::Integer
                ransacker full_key, type: :integer do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::int")
                end
              when ActiveModel::Type::Float, ActiveModel::Type::Decimal
                ransacker full_key, type: :float do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::float")
                end
              when ActiveModel::Type::DateTime, ActiveModel::Type::Time
                ransacker full_key, type: :datetime do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::timestamp")
                end
              when StoreModel::Types::One
                nested_model = type.model_class
                define_store_model_ransackers("#{jsonb_attr} -> '#{key}'", nested_model, full_key)
              when StoreModel::Types::Many
                nested_model = type.model_class

                nested_model.attribute_types.each do |nested_key, nested_type|
                  field = "#{jsonb_attr} -> '#{key}'"

                  ransacker "#{full_key}_#{nested_key}" do |val|
                    sql = <<~SQL.squish
                      EXISTS (
                        SELECT 1 FROM jsonb_array_elements(#{field}) AS item
                        WHERE item ->> '#{nested_key}' ILIKE '%#{sanitize_sql_like(val)}%'
                      )
                    SQL
                    Arel.sql(sql)
                  end
                end
              else
                # fallback: just extract as string
                ransacker full_key do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')")
                end
              end
            end
          end
        end
      end
    end
  end
end