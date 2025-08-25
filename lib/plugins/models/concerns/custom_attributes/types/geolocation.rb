# lib/plugins/models/concerns/custom_attributes/types/geolocation.rb
module Plugins
  module Models
    module Concerns
      module CustomAttributes
        module Types
          class Geolocation < Base
            EARTH_RADIUS_KM = 6371.0

            def type
              :geolocation
            end

            def cast(value)
              case value
              when String
                lat_str, lng_str = value.split(",", 2)
                lat = Float(lat_str) rescue nil
                lng = Float(lng_str) rescue nil
                return nil if lat.nil? || lng.nil?
                { lat: lat, lng: lng }
              when Hash
                lat = Float(value[:lat] || value["lat"]) rescue nil
                lng = Float(value[:lng] || value["lng"]) rescue nil
                return nil if lat.nil? || lng.nil?
                { lat: lat, lng: lng }
              else
                nil
              end
            end

            def serialize(value)
              v = cast(value)
              return if v.nil?
              "#{v[:lat]},#{v[:lng]}"
            end

            def deserialize(value)
              cast(value)
            end

            def self.define_custom_attributes_model_scopes(jsonb_attr, model_type, key, build_text_expr, build_exists_sql, method_name, array_root: false)
              connection = ActiveRecord::Base.connection

              if connection.adapter_name =~ /PostgreSQL/i
                extensions = connection.execute("SELECT * FROM pg_available_extensions WHERE installed_version IS NOT NULL")
                has_postgis = extensions.values.flatten.any? { |ext| ext.include?("postgis") }

                if has_postgis
                  define_postgis_scope(jsonb_attr, key, method_name, array_root)
                else
                  define_haversine_scope(jsonb_attr, key, method_name, array_root, build_exists_sql)
                end
              end
            end

            def self.define_postgis_scope(jsonb_attr, key, method_name, array_root)
              if array_root
                lat_expr = "(elem -> '#{key}' ->> 'lat')::float"
                lng_expr = "(elem -> '#{key}' ->> 'lng')::float"

                scope :"#{method_name}_within_distance", lambda { |lat, lng, km|
                  where(
                    build_exists_sql.call(
                      jsonb_attr,
                      "ST_DWithin(ST_MakePoint(#{lng_expr}, #{lat_expr})::geography, ST_MakePoint(?, ?)::geography, ? * 1000)"
                    ),
                    lng, lat, km
                  )
                }
              else
                lat_expr = "(#{model_type.table_name}.#{jsonb_attr} -> '#{key}' ->> 'lat')::float"
                lng_expr = "(#{model_type.table_name}.#{jsonb_attr} -> '#{key}' ->> 'lng')::float"

                scope :"#{method_name}_within_distance", lambda { |lat, lng, km|
                  where(
                    "ST_DWithin(ST_MakePoint(#{lng_expr}, #{lat_expr})::geography, ST_MakePoint(?, ?)::geography, ? * 1000)",
                    lng, lat, km
                  )
                }
              end
            end

            def self.define_haversine_scope(jsonb_attr, key, method_name, array_root, build_exists_sql)
              if array_root
                lat_expr = "(NULLIF(elem -> '#{key}' ->> 'lat', ''))::float"
                lng_expr = "(NULLIF(elem -> '#{key}' ->> 'lng', ''))::float"

                distance_sql = <<~SQL.squish
                  (2 * #{EARTH_RADIUS_KM} * ASIN(
                    SQRT(
                      POWER(SIN(((#{lat_expr} - ?) * pi()/180.0) / 2), 2) +
                      COS(? * pi()/180.0) * COS(#{lat_expr} * pi()/180.0) *
                      POWER(SIN(((#{lng_expr} - ?) * pi()/180.0) / 2), 2)
                    )
                  ))
                SQL

                scope :"#{method_name}_within_distance", lambda { |lat, lng, km|
                  lat = Float(lat) rescue nil
                  lng = Float(lng) rescue nil
                  km = Float(km) rescue nil
                  next none if lat.nil? || lng.nil? || km.nil?
                  where(build_exists_sql.call(jsonb_attr, "#{distance_sql} <= ?"), lat, lat, lng, km)
                }
              else
                lat_expr = "(NULLIF(#{model_type.table_name}.#{jsonb_attr} -> '#{key}' ->> 'lat', ''))::float"
                lng_expr = "(NULLIF(#{model_type.table_name}.#{jsonb_attr} -> '#{key}' ->> 'lng', ''))::float"

                distance_sql = <<~SQL.squish
                  (2 * #{EARTH_RADIUS_KM} * ASIN(
                    SQRT(
                      POWER(SIN(((#{lat_expr} - ?) * pi()/180.0) / 2), 2) +
                      COS(? * pi()/180.0) * COS(#{lat_expr} * pi()/180.0) *
                      POWER(SIN(((#{lng_expr} - ?) * pi()/180.0) / 2), 2)
                    )
                  ))
                SQL

                scope :"#{method_name}_within_distance", lambda { |lat, lng, km|
                  lat = Float(lat) rescue nil
                  lng = Float(lng) rescue nil
                  km = Float(km) rescue nil
                  next none if lat.nil? || lng.nil? || km.nil?
                  where("#{distance_sql} <= ?", lat, lat, lng, km)
                }
              end
            end

            def self.define_custom_attributes_model_ransackers(jsonb_attr, model_type, key, build_text_expr, build_exists_sql, method_name, array_root: false)
              if array_root
                ransacker :"#{method_name}_lat", type: :float do
                  Arel.sql("NULL") # Placeholder only
                end
                ransacker :"#{method_name}_lng", type: :float do
                  Arel.sql("NULL")
                end
              else
                ransacker :"#{method_name}_lat", type: :float do
                  Arel.sql("(NULLIF(#{model_type.table_name}.#{jsonb_attr} -> '#{key}' ->> 'lat', ''))::float")
                end
                ransacker :"#{method_name}_lng", type: :float do
                  Arel.sql("(NULLIF(#{model_type.table_name}.#{jsonb_attr} -> '#{key}' ->> 'lng', ''))::float")
                end
              end
            end
          end
        end
      end
    end
  end
end
