module Plugins
  module Models
    module Concerns
      module IdempotencyLockable
        extend ActiveSupport::Concern

        class_methods do
          def idempotency_lock!(key:, window: nil, &block)
            raise ArgumentError, "key is required for class-level idempotency_lock!" unless key.present?

            key = build_scoped_key(key, window)

            with_advisory_lock(key, timeout_seconds: 5, &block)
          end

          def build_scoped_key(base_key, window)
            return base_key unless window

            rounded = Time.at((Time.current.to_f / window).floor * window).in_time_zone
            "#{base_key}-#{rounded.to_i}"
          end

          def idempotency_key_fields
            [:id]
          end
        end

        def idempotency_lock!(key: nil, window: nil, key_fields: nil, &block)
          key ||= generate_idempotency_key(key_fields: key_fields)
          raise ArgumentError, "Could not determine idempotency_key" unless key

          scoped_key = self.class.build_scoped_key(key, window)

          self.idempotency_key ||= key if respond_to?(:idempotency_key=)
          if window && respond_to?(:idempotency_window=)
            self.idempotency_window ||= Time.at((Time.current.to_f / window).floor * window).in_time_zone
          end

          self.class.with_advisory_lock(scoped_key, timeout_seconds: 5, &block)
        end

        def generate_idempotency_key(key_fields: nil)
          fields = key_fields || self.class.idempotency_key_fields
          return nil if fields.empty? || !respond_to?(:attributes)

          raw = [self.class.name, *attributes.symbolize_keys.slice(*fields.map(&:to_sym)).values].join("-")
          Digest::SHA256.hexdigest(raw)
        end
      end
    end
  end
end