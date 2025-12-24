module Plugins
  module Models
    module Concerns
      module CustomAttributes

        autoload :Types, "plugins/models/concerns/custom_attributes/types"

        extend ActiveSupport::Concern

        included do
          include ::Plugins::EngineCallbacks
          after_plugins_initialization do
            ::Plugins::Models::Concerns::CustomAttributes::Types.register_classes!
          end
        end

        class_methods do
          def custom_attributes_definition(attribute_name, model_type, prefix: nil, accessor: false, ransackers: true, scopes: true)
            return unless ::ActiveRecord::Base.connection.table_exists?(self.table_name)
            check_jsonb_compatibility!
            include StoreModel::NestedAttributes

            attribute attribute_name, model_type.to_type

            prefix ||= attribute_name
            define_custom_attributes_model_accessors(attribute_name.to_s, model_type, prefix) if accessor
            define_custom_attributes_model_scopes(attribute_name.to_s, model_type, prefix) if scopes
            define_custom_attributes_model_ransackers(attribute_name.to_s, model_type, prefix) if ransackers && respond_to?(:ransacker)

            # current = self
            # while current < ActiveRecord::Base
            #   break if current.abstract_class?
            #   current.define_custom_attributes_model_ransackers(attribute_name.to_s, model_type, prefix) if ransackers && respond_to?(:ransacker)
            #   current = current.superclass
            # end
          end

          def check_jsonb_compatibility!
            adapter = ActiveRecord::Base.connection.adapter_name.downcase
            unless adapter.include?("postgresql")
              raise Plugins::ErrorsUnsupportedAdapterError,
                    "JSONB querying is only supported on PostgreSQL. Current adapter: #{adapter}"
            end
          end

          def define_custom_attributes_model_accessors(jsonb_attr, model_type, prefix = nil)
            model_type.attribute_types.each do |attr_key, attr_type|
              accessor_name = [prefix, attr_key].reject(&:blank?).join("_")
              next if attribute_names.include?(accessor_name.to_s)

              # getter
              define_method(accessor_name) do
                public_send(jsonb_attr)&.public_send(attr_key)
              end unless method_defined?(accessor_name)

              # setter
              define_method("#{accessor_name}=") do |value|
                model_instance = public_send(jsonb_attr) || self.class.attribute_types[jsonb_attr.to_s].deserialize({})
                public_send("#{jsonb_attr}=", model_instance)
                model_instance.public_send("#{attr_key}=", value)
              end unless method_defined?("#{accessor_name}=")

              # register virtual attribute
              next if attribute_types.key?(attr_key.to_s)
              case attr_type
              when ::StoreModel::Types::One
                default_value = model_type.new.public_send(attr_key)
                nested_klass = attr_type.model_klass
                attribute accessor_name, nested_klass.type#, default_value
                # accepts_nested_attributes_for attr_key, reject_if: :all_blank
              when ::StoreModel::Types::Many
                default_value = model_type.new.public_send(attr_key)
                nested_klass = attr_type.model_klass
                attribute accessor_name, nested_klass.to_array_type#, default_value
                # accepts_nested_attributes_for attr_key, reject_if: :all_blank
              else
                safe_type = attr_type.duplicable? ? attr_type.dup : attr_type.class.new
                attribute accessor_name, safe_type
              end
            end
          end

          def define_custom_attributes_model_scopes(jsonb_attr, model_type, prefix = nil, array_root: false)
            build_text_expr = ->(key, use_elem:) { use_elem ? "NULLIF(elem ->> '#{key}', '')" : "NULLIF(#{self.table_name}.#{jsonb_attr} ->> '#{key}', '')" }
            build_exists_sql = ->(array_path_sql, predicate_sql) { "EXISTS (SELECT 1 FROM jsonb_array_elements(#{self.table_name}.#{array_path_sql}) AS elem WHERE #{predicate_sql})" }
            bool_type = ActiveRecord::Type::Boolean.new

            model_type.attribute_types.each do |key, type|
              method_name = [prefix, key].reject(&:blank?).join("_")

              case type
              when ActiveModel::Type::String
                if array_root
                  scope :"with_#{method_name}", ->(v) { where(build_exists_sql.call(jsonb_attr, "(elem ->> '#{key}') = ?"), v.to_s) if v }
                  scope :"like_#{method_name}", ->(v) { where(build_exists_sql.call(jsonb_attr, "(elem ->> '#{key}') ILIKE ?"), "%#{sanitize_sql_like(v.to_s)}%") if v }
                else
                  scope :"with_#{method_name}", ->(v) { where("(#{self.table_name}.#{jsonb_attr} ->> ?) = ?", key, v.to_s) if v }
                  scope :"like_#{method_name}", ->(v) { where("(#{self.table_name}.#{jsonb_attr} ->> ?) ILIKE ?", key, "%#{sanitize_sql_like(v.to_s)}%") if v }
                end

              when ActiveModel::Type::Integer
                safe_cast = ->(v) { Integer(v) rescue nil }
                cast = "::int"
                if array_root
                  scope :"#{method_name}_eq", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} = ?"), v) if v }
                  scope :"#{method_name}_gt", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} > ?"), v) if v }
                  scope :"#{method_name}_lt", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} < ?"), v) if v }
                  scope :"#{method_name}_gteq", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} >= ?"), v) if v }
                  scope :"#{method_name}_lteq", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} <= ?"), v) if v }
                else
                  scope :"#{method_name}_eq", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) = ?", v) if v }
                  scope :"#{method_name}_gt", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) > ?", v) if v }
                  scope :"#{method_name}_lt", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) < ?", v) if v }
                  scope :"#{method_name}_gteq", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) >= ?", v) if v }
                  scope :"#{method_name}_lteq", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) <= ?", v) if v }
                end

              when ActiveModel::Type::Float, ActiveModel::Type::Decimal
                safe_cast = ->(v) { Float(v) rescue nil }
                cast = "::float"
                if array_root
                  %i[eq gt lt gteq lteq].each do |op|
                    scope :"#{method_name}_#{op}", ->(v) { v = safe_cast[v]; next unless v; sql_op = { eq: "=", gt: ">", lt: "<", gteq: ">=", lteq: "<=" }[op]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} #{sql_op} ?"), v) }
                  end
                else
                  %i[eq gt lt gteq lteq].each do |op|
                    scope :"#{method_name}_#{op}", ->(v) { v = safe_cast[v]; next unless v; sql_op = { eq: "=", gt: ">", lt: "<", gteq: ">=", lteq: "<=" }[op]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) #{sql_op} ?", v) }
                  end
                end

              when ActiveModel::Type::Boolean
                if array_root
                  scope :"#{method_name}_eq", ->(v) { v = bool_type.cast(v); where(build_exists_sql.call(jsonb_attr, "(#{build_text_expr.call(key, use_elem: true)}::boolean) = ?"), v) unless v.nil? }
                  scope :"#{method_name}_not_eq", ->(v) { v = bool_type.cast(v); where.not(build_exists_sql.call(jsonb_attr, "(#{build_text_expr.call(key, use_elem: true)}::boolean) = ?"), v) unless v.nil? }
                else
                  scope :"#{method_name}_eq", ->(v) { v = bool_type.cast(v); where("(#{build_text_expr.call(key, use_elem: false)}::boolean) = ?", v) unless v.nil? }
                  scope :"#{method_name}_not_eq", ->(v) { v = bool_type.cast(v); where.not("(#{build_text_expr.call(key, use_elem: false)}::boolean) = ?", v) unless v.nil? }
                end

              when ActiveModel::Type::Date
                safe_cast = ->(v) { v.to_date rescue nil }
                cast = "::date"
                if array_root
                  scope :"#{method_name}_on", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} = ?"), v) if v }
                  scope :"#{method_name}_before", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} < ?"), v) if v }
                  scope :"#{method_name}_after", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} > ?"), v) if v }
                else
                  scope :"#{method_name}_on", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) = ?", v) if v }
                  scope :"#{method_name}_before", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) < ?", v) if v }
                  scope :"#{method_name}_after", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) > ?", v) if v }
                end

              when ActiveModel::Type::DateTime, ActiveModel::Type::Time
                safe_cast = ->(v) { v.to_time rescue nil }
                cast = "::timestamp"
                if array_root
                  scope :"#{method_name}_on", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} = ?"), v) if v }
                  scope :"#{method_name}_before", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} < ?"), v) if v }
                  scope :"#{method_name}_after", ->(v) { v = safe_cast[v]; where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} > ?"), v) if v }
                else
                  scope :"#{method_name}_on", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) = ?", v) if v }
                  scope :"#{method_name}_before", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) < ?", v) if v }
                  scope :"#{method_name}_after", ->(v) { v = safe_cast[v]; where("(#{build_text_expr.call(key, use_elem: false)}#{cast}) > ?", v) if v }
                end

              when StoreModel::Types::One
                nested_model = type.model_klass
                define_custom_attributes_model_scopes("#{jsonb_attr} -> '#{key}'", nested_model, method_name, array_root: array_root)

              when StoreModel::Types::Many
                nested_model = type.model_klass
                define_custom_attributes_model_scopes("#{jsonb_attr} -> '#{key}'", nested_model, method_name, array_root: true)

              else
                # fallback to string
                if array_root
                  scope :"with_#{method_name}", ->(v) { where(build_exists_sql.call(jsonb_attr, "elem ->> '#{key}' = ?"), v.to_s) if v }
                  scope :"like_#{method_name}", ->(v) { where(build_exists_sql.call(jsonb_attr, "elem ->> '#{key}' ILIKE ?"), "%#{sanitize_sql_like(v.to_s)}%") if v }
                else
                  scope :"with_#{method_name}", ->(v) { where("(#{build_text_expr.call(key, use_elem: false)}) = ?", v.to_s) if v }
                  scope :"like_#{method_name}", ->(v) { where("(#{build_text_expr.call(key, use_elem: false)}) ILIKE ?", "%#{sanitize_sql_like(v.to_s)}%") if v }
                end
              end
            end
          end

          def define_custom_attributes_model_ransackers(jsonb_attr, model_type, prefix = nil, array_root: false)
            build_text_expr = ->(key, use_elem:) { use_elem ? "NULLIF(elem ->> '#{key}', '')" : "NULLIF(#{self.table_name}.#{jsonb_attr} ->> '#{key}', '')" }
            build_exists_sql = ->(array_path_sql, predicate_sql) { "EXISTS (SELECT 1 FROM jsonb_array_elements(#{self.table_name}.#{array_path_sql}) AS elem WHERE #{predicate_sql})" }
            bool_type = ActiveRecord::Type::Boolean.new

            model_type.attribute_types.each do |key, type|
              method_name = [prefix, key].reject(&:blank?).join("_")

              case type
              when ActiveModel::Type::String
                ransacker method_name do
                  if array_root
                    Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)} ILIKE '%%'"))
                  else
                    Arel.sql(build_text_expr.call(key, use_elem: false))
                  end
                end

              when ActiveModel::Type::Integer
                safe_cast = ->(v) { Integer(v) rescue nil }
                ransacker method_name, type: :integer do |parent|
                  v = safe_cast[parent]
                  next nil unless v
                  if array_root
                    Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::int IS NOT NULL"))
                  else
                    Arel.sql("#{build_text_expr.call(key, use_elem: false)}::int")
                  end
                end

              when ActiveModel::Type::Float, ActiveModel::Type::Decimal
                safe_cast = ->(v) { Float(v) rescue nil }
                ransacker method_name, type: :float do |parent|
                  v = safe_cast[parent]
                  next nil unless v
                  if array_root
                    Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::float IS NOT NULL"))
                  else
                    Arel.sql("#{build_text_expr.call(key, use_elem: false)}::float")
                  end
                end

              when ActiveModel::Type::Boolean
                ransacker method_name, type: :boolean do |parent|
                  v = bool_type.cast(parent)
                  next nil if v.nil?
                  if array_root
                    Arel.sql("EXISTS (SELECT 1 FROM jsonb_array_elements(#{self.table_name}.#{jsonb_attr}) AS elem WHERE (elem ->> '#{key}')::boolean = #{v})")
                  else
                    Arel.sql("(#{self.table_name}.#{jsonb_attr} ->> '#{key}')::boolean = #{v}")
                  end
                end

              when ActiveModel::Type::Date
                safe_cast = ->(v) { v.to_date rescue nil }
                ransacker method_name, type: :date do |parent|
                  v = safe_cast[parent]
                  next nil unless v
                  if array_root
                    Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::date IS NOT NULL"))
                  else
                    Arel.sql("#{build_text_expr.call(key, use_elem: false)}::date")
                  end
                end

              when ActiveModel::Type::DateTime, ActiveModel::Type::Time
                safe_cast = ->(v) { v.to_time rescue nil }
                ransacker method_name, type: :datetime do |parent|
                  v = safe_cast[parent]
                  next nil unless v
                  if array_root
                    Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::timestamp IS NOT NULL"))
                  else
                    Arel.sql("#{build_text_expr.call(key, use_elem: false)}::timestamp")
                  end
                end

              when StoreModel::Types::One
                nested_model = type.model_klass
                define_custom_attributes_model_ransackers("#{jsonb_attr} -> '#{key}'", nested_model, method_name, array_root: array_root)

              when StoreModel::Types::Many
                nested_model = type.model_klass
                define_custom_attributes_model_ransackers("#{jsonb_attr} -> '#{key}'", nested_model, method_name, array_root: true)

              else
                ransacker method_name do
                  if array_root
                    Arel.sql(build_exists_sql.call(jsonb_attr, "elem ->> '#{key}' IS NOT NULL"))
                  else
                    Arel.sql("#{jsonb_attr} ->> '#{key}'")
                  end
                end
              end
            end
          end

          def store_model_klass_of attr
            type_for_attribute(attr.to_s).model_klass rescue nil
          end

          def patch_store_model_class!(base:, mod:, name:)
            @_store_model_metadata_cache ||= {}

            return @_store_model_metadata_cache[name] if @_store_model_metadata_cache.key?(name)
            return unless base

            derived = Class.new(base)
            derived.include(mod)

            const_set(name, derived) unless const_defined?(name, false)

            klass = const_get(name)

            @_store_model_metadata_cache[name] = klass
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
#           def custom_attributes_definition(attribute_name, model_type, prefix: nil, accessor: false, ransacker: true, scopes: true)
#             return unless ::ActiveRecord::Base.connection.table_exists?(self.table_name)
#             check_jsonb_compatibility!
#             include StoreModel::NestedAttributes

#             attribute attribute_name, model_type.to_type

#             prefix ||= attribute_name

#             current = self
#             while current < ActiveRecord::Base
#               break if current.abstract_class?
#               current.define_custom_attributes_model_accessors(attribute_name.to_s, model_type, prefix) if accessor
#               current.define_custom_attributes_model_scopes(attribute_name.to_s, model_type, prefix) if scopes
#               current.define_custom_attributes_model_ransackers(attribute_name.to_s, model_type, prefix) if ransacker
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

#           def define_custom_attributes_model_accessors(jsonb_attr, model_type, prefix = nil)
#             model_type.attribute_types.each do |attr_key, attr_type|
#               accessor_name = [prefix, attr_key].reject { |c| c.nil? || c.to_s.strip.empty? }.join("_")
#               if attribute_names.include?(accessor_name.to_s)
#                 next
#                 #raise ArgumentError, "Cannot define custom accessor for '#{attr_key}'; it conflicts with existing attribute."
#               end
#               # Define getter unless already defined
#               unless method_defined?(accessor_name)
#                 define_method(accessor_name) do
#                   public_send(attribute_name)&.public_send(attr_key)
#                 end
#               end

#               # Define setter unless already defined
#               unless method_defined?("#{accessor_name}=")
#                 define_method("#{accessor_name}=") do |value|
#                   model_instance = public_send(attribute_name)

#                   unless model_instance
#                     model_instance = self.class.attribute_types[attribute_name.to_s].deserialize({})
#                     public_send("#{attribute_name}=", model_instance)
#                   end

#                   model_instance.public_send("#{attr_key}=", value)
#                 end
#               end

#               # Register as virtual attribute with correct type and default
#               unless attribute_types.key?(attr_key.to_s)
#                 case attr_type
#                 when ::StoreModel::Types::One
#                   default_value = model_type.new.public_send(attr_key)
#                   nested_klass = attr_type.model_klass
#                   attribute accessor_name, nested_klass.type, default_value
#                   accepts_nested_attributes_for attr_key, reject_if: :all_blank
#                 when ::StoreModel::Types::Many
#                   default_value = model_type.new.public_send(attr_key)
#                   nested_klass = attr_type.model_klass
#                   attribute accessor_name, nested_klass.to_array_type, default_value
#                   accepts_nested_attributes_for attr_key, reject_if: :all_blank
#                 when ::StoreModel::Types::OnePolymorphic, ::StoreModel::Types::ManyPolymorphic
#                 else
#                   safe_type = attr_type.duplicable? ? attr_type.dup : attr_type.class.new
#                   attribute accessor_name, safe_type, default: default_value
#                   # default_value = model_type.new.public_send(attr_key)
#                   # attribute attr_key, attr_type.class.new, default: default_value
#                 end
#               end
#             end
#           end

#           # Recursively define scopes for JSONB-backed StoreModel attributes (including arrays).
#           # - jsonb_attr: SQL path to the JSONB object/array (e.g., "custom_attrs", "custom_attrs -> 'address'")
#           # - model_type: StoreModel::Model class for the current JSON level
#           # - prefix:     scope name prefix (composed as you descend, e.g., "address_city")
#           # - array_root: when true, jsonb_attr points to a JSONB array; we expand it via jsonb_array_elements(...)
#           def define_custom_attributes_model_scopes(jsonb_attr, model_type, prefix = nil, array_root: false)
#             # helpers
#             build_text_expr = ->(key, use_elem:) do
#               if use_elem
#                 "NULLIF(elem ->> '#{key}', '')"
#               else
#                 "NULLIF(#{self.table_name}.#{jsonb_attr} ->> '#{key}', '')"
#               end
#             end

#             build_exists_sql = ->(array_path_sql, predicate_sql) do
#               <<~SQL.squish
#                 EXISTS (
#                   SELECT 1
#                   FROM jsonb_array_elements(#{self.table_name}.#{array_path_sql}) AS elem
#                   WHERE #{predicate_sql}
#                 )
#               SQL
#             end

#             model_type.attribute_types.each do |key, type|
#               method_name = [prefix, key].compact.join("_")

#               case type
#               # -----------------------
#               # String-like
#               # -----------------------
#               when ActiveModel::Type::String
#                 if array_root
#                   scope :"with_#{method_name}", ->(value) {
#                     where(build_exists_sql.call(jsonb_attr, "(elem ->> '#{key}') = ?"), value)
#                   }
#                   scope :"like_#{method_name}", ->(value) {
#                     where(build_exists_sql.call(jsonb_attr, "(elem ->> '#{key}') ILIKE ?"), "%#{sanitize_sql_like(value)}%")
#                   }
#                   scope :"not_#{method_name}", ->(value) {
#                     where.not(build_exists_sql.call(jsonb_attr, "(elem ->> '#{key}') = ?"), value)
#                   }
#                   scope :"not_like_#{method_name}", ->(value) {
#                     where.not(build_exists_sql.call(jsonb_attr, "(elem ->> '#{key}') ILIKE ?"), "%#{sanitize_sql_like(value)}%")
#                   }
#                 else
#                   scope :"with_#{method_name}", ->(value) {
#                     where("(#{self.table_name}.#{jsonb_attr} ->> ?) = ?", key, value)
#                   }
#                   scope :"like_#{method_name}", ->(value) {
#                     where("(#{self.table_name}.#{jsonb_attr} ->> ?) ILIKE ?", key, "%#{sanitize_sql_like(value)}%")
#                   }
#                   scope :"not_#{method_name}", ->(value) {
#                     where.not("(#{self.table_name}.#{jsonb_attr} ->> ?) = ?", key, value)
#                   }
#                   scope :"not_like_#{method_name}", ->(value) {
#                     where.not("(#{self.table_name}.#{jsonb_attr} ->> ?) ILIKE ?", key, "%#{sanitize_sql_like(value)}%")
#                   }
#                 end

#               # -----------------------
#               # Integer
#               # -----------------------
#               when ActiveModel::Type::Integer
#                 if array_root
#                   scope :"#{method_name}_eq",   ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::int = ?"), v) }
#                   scope :"#{method_name}_gt",   ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::int > ?"), v) }
#                   scope :"#{method_name}_lt",   ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::int < ?"), v) }
#                   scope :"#{method_name}_gteq", ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::int >= ?"), v) }
#                   scope :"#{method_name}_lteq", ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::int <= ?"), v) }
#                 else
#                   scope :"#{method_name}_eq",   ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::int = ?", key, v) }
#                   scope :"#{method_name}_gt",   ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::int > ?", key, v) }
#                   scope :"#{method_name}_lt",   ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::int < ?", key, v) }
#                   scope :"#{method_name}_gteq", ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::int >= ?", key, v) }
#                   scope :"#{method_name}_lteq", ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::int <= ?", key, v) }
#                 end

#               # -----------------------
#               # Float & Decimal (mirror your ransackers → cast to ::float)
#               # -----------------------
#               when ActiveModel::Type::Float, ActiveModel::Type::Decimal
#                 cast = "::float"
#                 if array_root
#                   scope :"#{method_name}_eq",   ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} = ?"), v) }
#                   scope :"#{method_name}_gt",   ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} > ?"), v) }
#                   scope :"#{method_name}_lt",   ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} < ?"), v) }
#                   scope :"#{method_name}_gteq", ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} >= ?"), v) }
#                   scope :"#{method_name}_lteq", ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} <= ?"), v) }
#                 else
#                   scope :"#{method_name}_eq",   ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')#{cast} = ?", key, v) }
#                   scope :"#{method_name}_gt",   ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')#{cast} > ?", key, v) }
#                   scope :"#{method_name}_lt",   ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')#{cast} < ?", key, v) }
#                   scope :"#{method_name}_gteq", ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')#{cast} >= ?", key, v) }
#                   scope :"#{method_name}_lteq", ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')#{cast} <= ?", key, v) }
#                 end

#               # -----------------------
#               # Boolean
#               # -----------------------
#               when ActiveModel::Type::Boolean
#                 bool = ActiveRecord::Type::Boolean.new
#                 if array_root
#                   scope :"#{method_name}_eq",     ->(v) { where(build_exists_sql.call(jsonb_attr, "(#{build_text_expr.call(key, use_elem: true)}::boolean) = ?"), bool.cast(v)) }
#                   scope :"#{method_name}_not_eq", ->(v) { where.not(build_exists_sql.call(jsonb_attr, "(#{build_text_expr.call(key, use_elem: true)}::boolean) = ?"), bool.cast(v)) }
#                 else
#                   scope :"#{method_name}_eq",     ->(v) { where("(NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::boolean) = ?", key, bool.cast(v)) }
#                   scope :"#{method_name}_not_eq", ->(v) { where.not("(NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::boolean) = ?", key, bool.cast(v)) }
#                 end

#               # -----------------------
#               # Date (compare as DATE)
#               # -----------------------
#               when ActiveModel::Type::Date
#                 if array_root
#                   scope :"#{method_name}_on",     ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::date = ?"),  v.to_date) }
#                   scope :"#{method_name}_before", ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::date < ?"),  v.to_date) }
#                   scope :"#{method_name}_after",  ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::date > ?"),  v.to_date) }
#                 else
#                   scope :"#{method_name}_on",     ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::date = ?", key, v.to_date) }
#                   scope :"#{method_name}_before", ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::date < ?", key, v.to_date) }
#                   scope :"#{method_name}_after",  ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::date > ?", key, v.to_date) }
#                 end

#               # -----------------------
#               # DateTime / Time (compare as TIMESTAMP)
#               # -----------------------
#               when ActiveModel::Type::DateTime, ActiveModel::Type::Time
#                 if array_root
#                   scope :"#{method_name}_on",     ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::timestamp = ?"),  v.to_time) }
#                   scope :"#{method_name}_before", ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::timestamp < ?"),  v.to_time) }
#                   scope :"#{method_name}_after",  ->(v) { where(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}::timestamp > ?"),  v.to_time) }
#                 else
#                   scope :"#{method_name}_on",     ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::timestamp = ?", key, v.to_time) }
#                   scope :"#{method_name}_before", ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::timestamp < ?", key, v.to_time) }
#                   scope :"#{method_name}_after",  ->(v) { where("NULLIF(#{self.table_name}.#{jsonb_attr} ->> ?, '')::timestamp > ?", key, v.to_time) }
#                 end

#               # -----------------------
#               # Nested object
#               # -----------------------
#               when StoreModel::Types::One
#                 nested_model = type.model_class
#                 # Keep the context (if we were already inside an array, descendants will still be array-rooted)
#                 define_custom_attributes_model_scopes("#{jsonb_attr} -> '#{key}'", nested_model, method_name, array_root: array_root)

#               # -----------------------
#               # Array of objects
#               # -----------------------
#               when StoreModel::Types::Many
#                 nested_model = type.model_class
#                 # Switch to array context when diving into the items of this array
#                 define_custom_attributes_model_scopes("#{jsonb_attr} -> '#{key}'", nested_model, method_name, array_root: true)

#               # Polymorphic and unknown types — skip or treat as strings
#               when StoreModel::Types::OnePolymorphic, StoreModel::Types::ManyPolymorphic
#                 # no-op for now; requires discriminator handling
#               else
#                 # Fallback → treat as string
#                 if array_root
#                   scope :"with_#{method_name}", ->(value) {
#                     where(build_exists_sql.call(jsonb_attr, "(elem ->> '#{key}') = ?"), value.to_s)
#                   }
#                   scope :"like_#{method_name}", ->(value) {
#                     where(build_exists_sql.call(jsonb_attr, "(elem ->> '#{key}') ILIKE ?"), "%#{sanitize_sql_like(value)}%")
#                   }
#                 else
#                   scope :"with_#{method_name}", ->(value) {
#                     where("(#{self.table_name}.#{jsonb_attr} ->> ?) = ?", key, value.to_s)
#                   }
#                   scope :"like_#{method_name}", ->(value) {
#                     where("(#{self.table_name}.#{jsonb_attr} ->> ?) ILIKE ?", key, "%#{sanitize_sql_like(value)}%")
#                   }
#                 end
#               end
#             end
#           end

#           def define_custom_attributes_model_ransackers(jsonb_attr, model_type, prefix = nil, array_root: false)
#             build_text_expr = ->(key, use_elem:) do
#               if use_elem
#                 "NULLIF(elem ->> '#{key}', '')"
#               else
#                 "NULLIF(#{self.table_name}.#{jsonb_attr} ->> '#{key}', '')"
#               end
#             end

#             build_exists_sql = ->(array_path_sql, predicate_sql) do
#               <<~SQL.squish
#                 EXISTS (
#                   SELECT 1
#                   FROM jsonb_array_elements(#{self.table_name}.#{array_path_sql}) AS elem
#                   WHERE #{predicate_sql}
#                 )
#               SQL
#             end

#             model_type.attribute_types.each do |key, type|
#               method_name = [prefix, key].compact.join("_")

#               case type
#               when ActiveModel::Type::String
#                 if array_root
#                   ransacker method_name do
#                     Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)} ILIKE '%%'"))
#                   end
#                 else
#                   ransacker method_name do
#                     Arel.sql(build_text_expr.call(key, use_elem: false))
#                   end
#                 end

#               when ActiveModel::Type::Integer
#                 cast = "::int"
#                 if array_root
#                   ransacker method_name, type: :integer do
#                     Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} IS NOT NULL"))
#                   end
#                 else
#                   ransacker method_name, type: :integer do
#                     Arel.sql("#{build_text_expr.call(key, use_elem: false)}#{cast}")
#                   end
#                 end

#               when ActiveModel::Type::Float, ActiveModel::Type::Decimal
#                 cast = "::float"
#                 if array_root
#                   ransacker method_name, type: :float do
#                     Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} IS NOT NULL"))
#                   end
#                 else
#                   ransacker method_name, type: :float do
#                     Arel.sql("#{build_text_expr.call(key, use_elem: false)}#{cast}")
#                   end
#                 end

#               when ActiveModel::Type::Boolean
#                 bool = ActiveRecord::Type::Boolean.new
#                 if array_root
#                   ransacker method_name, type: :boolean do |parent|
#                     # Properly cast input to boolean
#                     Arel.sql(build_exists_sql.call(jsonb_attr, "(#{build_text_expr.call(key, use_elem: true)}::boolean) = #{bool.cast(parent)}"))
#                   end
#                 else
#                   ransacker method_name, type: :boolean do |parent|
#                     Arel.sql("(#{build_text_expr.call(key, use_elem: false)}::boolean) = #{bool.cast(parent)}")
#                   end
#                 end

#               when ActiveModel::Type::Date
#                 cast = "::date"
#                 if array_root
#                   ransacker method_name, type: :date do
#                     Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} IS NOT NULL"))
#                   end
#                 else
#                   ransacker method_name, type: :date do
#                     Arel.sql("#{build_text_expr.call(key, use_elem: false)}#{cast}")
#                   end
#                 end

#               when ActiveModel::Type::DateTime, ActiveModel::Type::Time
#                 cast = "::timestamp"
#                 if array_root
#                   ransacker method_name, type: :datetime do
#                     Arel.sql(build_exists_sql.call(jsonb_attr, "#{build_text_expr.call(key, use_elem: true)}#{cast} IS NOT NULL"))
#                   end
#                 else
#                   ransacker method_name, type: :datetime do
#                     Arel.sql("#{build_text_expr.call(key, use_elem: false)}#{cast}")
#                   end
#                 end

#               when StoreModel::Types::One
#                 nested_model = type.model_class
#                 define_custom_attributes_model_ransackers("#{jsonb_attr} -> '#{key}'", nested_model, method_name, array_root: array_root)

#               when StoreModel::Types::Many
#                 nested_model = type.model_class
#                 define_custom_attributes_model_ransackers("#{jsonb_attr} -> '#{key}'", nested_model, method_name, array_root: true)

#               else
#                 # fallback for polymorphic/unknown
#                 if array_root
#                   ransacker method_name do
#                     Arel.sql(build_exists_sql.call(jsonb_attr, "elem ->> '#{key}' IS NOT NULL"))
#                   end
#                 else
#                   ransacker method_name do
#                     Arel.sql("#{jsonb_attr} ->> '#{key}'")
#                   end
#                 end
#               end
#             end
#           end
#         end
#       end
#     end
#   end
# end

