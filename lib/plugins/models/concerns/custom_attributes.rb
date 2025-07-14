require 'byebug'
module Plugins
  module Models
    module Concerns
      module CustomAttributes
        extend ActiveSupport::Concern

        class_methods do
          def custom_attributes_definition(attribute_name, model_type, prefix: nil, accessor: false)
            check_jsonb_compatibility!
            include StoreModel::NestedAttributes

            attribute attribute_name, model_type.to_type

            if accessor
              model_type.attribute_types.each do |attr_key, attr_type|
                if attribute_names.include?(attr_key.to_s)
                  next
                  #raise ArgumentError, "Cannot define custom accessor for '#{attr_key}'; it conflicts with existing attribute."
                end
                # Define getter unless already defined
                unless method_defined?(attr_key)
                  define_method(attr_key) do
                    public_send(attribute_name)&.public_send(attr_key)
                  end
                end

                # Define setter unless already defined
                unless method_defined?("#{attr_key}=")
                  define_method("#{attr_key}=") do |value|
                    model_instance = public_send(attribute_name)

                    unless model_instance
                      model_instance = self.class.attribute_types[attribute_name.to_s].deserialize({})
                      public_send("#{attribute_name}=", model_instance)
                    end

                    model_instance.public_send("#{attr_key}=", value)
                  end
                end

                # Register as virtual attribute with correct type and default
                unless attribute_types.key?(attr_key.to_s)
                  case attr_type
                  when ::StoreModel::Types::One
                    default_value = model_type.new.public_send(attr_key)
                    nested_klass = attr_type.model_class
                    attribute attr_key, nested_klass.type, default_value
                    accepts_nested_attributes_for attr_key, reject_if: :all_blank
                  when ::StoreModel::Types::Many
                    default_value = model_type.new.public_send(attr_key)
                    nested_klass = attr_type.model_class
                    attribute attr_key, nested_klass.to_array_type, default_value
                    accepts_nested_attributes_for attr_key, reject_if: :all_blank
                  when ::StoreModel::Types::OnePolymorphic, ::StoreModel::Types::ManyPolymorphic
                  else
                    safe_type = attr_type.duplicable? ? attr_type.dup : attr_type.class.new
                    attribute attr_key, safe_type, default: default_value
                    # default_value = model_type.new.public_send(attr_key)
                    # attribute attr_key, attr_type.class.new, default: default_value
                  end
                end
              end
            else
              prefix ||= attribute_name
            end

            current = self
            while current < ActiveRecord::Base
              break if current.abstract_class?
              current.send(:define_store_model_ransackers, attribute_name.to_s, model_type, prefix)
              current = current.superclass
            end
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
              base_key = [prefix, key].compact.join("_")

              accessor_key = if attribute_names.include?(base_key)
                               "#{jsonb_attr}_#{base_key}"
                             else
                               base_key
                             end

              case type
              when ActiveModel::Type::String
                ransacker accessor_key do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')")
                end
              when ActiveModel::Type::Integer
                ransacker accessor_key, type: :integer do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::int")
                end
              when ActiveModel::Type::Float, ActiveModel::Type::Decimal
                ransacker accessor_key, type: :float do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::float")
                end
              when ActiveModel::Type::DateTime, ActiveModel::Type::Time
                ransacker accessor_key, type: :datetime do
                  Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::timestamp")
                end
              when StoreModel::Types::One
                nested_model = type.model_class
                define_store_model_ransackers("#{jsonb_attr} -> '#{key}'", nested_model, accessor_key)
              when StoreModel::Types::Many
                nested_model = type.model_class
                nested_model.attribute_types.each do |nested_key, _|
                  field = "#{jsonb_attr} -> '#{key}'"
                  ransacker "#{accessor_key}_#{nested_key}" do |val|
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
                ransacker accessor_key do
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

# module Plugins
#   module Models
#     module Concerns
#       module CustomAttributes
#         extend ActiveSupport::Concern

#         class_methods do
#           def custom_attributes_definition(attribute_name, model_type, prefix: nil, accessor: false)
#             check_jsonb_compatibility!
#             include StoreModel::NestedAttributes
#             attribute attribute_name, model_type.to_type

#             if accessor
#               # Define accessors and virtual attributes
#               model_type.attribute_types.each_key do |attr_key|
#                 define_method(attr_key) do
#                   public_send(attribute_name)&.public_send(attr_key)
#                 end

#                 define_method("#{attr_key}=") do |value|
#                   model_instance = public_send(attribute_name)

#                   unless model_instance
#                     model_instance = self.class.attribute_types[attribute_name.to_s].deserialize({})
#                     public_send("#{attribute_name}=", model_instance)
#                   end

#                   model_instance.public_send("#{attr_key}=", value)
#                 end

#                 # Register as virtual attribute for mass-assignment support
#                 attribute attr_key
#               end
#             else
#               prefix ||= attribute_name
#             end

#             current = self
#             while current < ActiveRecord::Base
#               break if current.abstract_class?
#               current.send(:define_store_model_ransackers, attribute_name.to_s, model_type, prefix)
#               current = current.superclass
#             end
#           end

#           def check_jsonb_compatibility!
#             adapter = ActiveRecord::Base.connection.adapter_name.downcase
#             unless adapter.include?("postgresql")
#               raise Plugins::ErrorsUnsupportedAdapterError,
#                     "JSONB querying is only supported on PostgreSQL. Current adapter: #{adapter}"
#             end
#           end

#           def define_store_model_ransackers(jsonb_attr, model_class, prefix = nil)
#             accessor_keys = []
#             model_class.attribute_types.each do |key, type|
#               base_key = [prefix, key].compact.join("_")

#               # Detect conflict with existing attributes
#               accessor_key = if attribute_names.include?(base_key)
#                                "#{jsonb_attr}_#{base_key}"
#                              else
#                                base_key
#                              end

#               accessor_keys << accessor_key.to_s

#               case type
#               when ActiveModel::Type::String
#                 ransacker accessor_key do
#                   Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')")
#                 end
#               when ActiveModel::Type::Integer
#                 ransacker accessor_key, type: :integer do
#                   Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::int")
#                 end
#               when ActiveModel::Type::Float, ActiveModel::Type::Decimal
#                 ransacker accessor_key, type: :float do
#                   Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::float")
#                 end
#               when ActiveModel::Type::DateTime, ActiveModel::Type::Time
#                 ransacker accessor_key, type: :datetime do
#                   Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')::timestamp")
#                 end
#               when StoreModel::Types::One
#                 nested_model = type.model_class
#                 define_store_model_ransackers("#{jsonb_attr} -> '#{key}'", nested_model, accessor_key)
#               when StoreModel::Types::Many
#                 nested_model = type.model_class

#                 nested_model.attribute_types.each do |nested_key, nested_type|
#                   field = "#{jsonb_attr} -> '#{key}'"

#                   ransacker "#{accessor_key}_#{nested_key}" do |val|
#                     sql = <<~SQL.squish
#                       EXISTS (
#                         SELECT 1 FROM jsonb_array_elements(#{field}) AS item
#                         WHERE item ->> '#{nested_key}' ILIKE '%#{sanitize_sql_like(val)}%'
#                       )
#                     SQL
#                     Arel.sql(sql)
#                   end
#                 end
#               else
#                 # fallback: just extract as string
#                 ransacker accessor_key do
#                   Arel.sql("NULLIF(#{jsonb_attr} ->> '#{key}', '')")
#                 end
#               end
#             end

#           end
#         end
#       end
#     end
#   end
# end