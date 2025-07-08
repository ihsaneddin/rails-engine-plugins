module Plugins
  module Models
    module Concerns
      module IdempotencyLockable
        extend ActiveSupport::Concern

        # Example usage:
        #
        # class PaymentEntry < ApplicationRecord
        #   include Plugins::Models::Concerns::IdempotencyLockable
        #
        #   def self.idempotency_key_fields
        #     [:payable_type, :payable_id, :amount, :currency]
        #   end
        #
        #   def process!
        #     idempotency_lock!(window: 5.seconds) do
        #       update!(status: :processed)
        #     end
        #   end
        # end
        #
        # entry = PaymentEntry.new(payable_type: "Invoice", payable_id: 123, amount: 1000, currency: "USD")
        # entry.process! # will only run once within the window (via advisory lock)
        #
        # You can also run class-level lock:
        #
        # PaymentEntry.idempotency_lock!(key: "batch-import", window: 10.seconds) do
        #   PaymentEntry.import_bulk!
        # end

        included do
          unless respond_to?(:with_advisory_lock)
            raise LoadError, "`with_advisory_lock` is not defined. Please install the `with_advisory_lock` gem or define the method."
          end
        end

        class_methods do

          # Executes a block under an advisory lock using the given key.
          # Useful for ensuring an operation is not run more than once across threads or processes.
          #
          # @param key [String] a unique string representing this operation
          # @param window [Integer, nil] optional deduplication window in seconds
          #
          # @example Simple usage
          #   idempotency_lock!(key: "sync-job") do
          #     perform_sync!
          #   end
          #
          # @example With a 10-second time window
          #   idempotency_lock!(key: "bulk-import", window: 10.seconds) do
          #     BulkImport.run!
          #   end
          def idempotency_lock!(key:, window: nil, &block)
            raise ArgumentError, "key is required for class-level idempotency_lock!" unless key.present?

            key = build_idempotency_scoped_key(key, window)

            with_advisory_lock(key, timeout_seconds: 5, &block)
          end

          # Builds a lock key string that includes time window information if given.
          #
          # @param base_key [String]
          # @param window [Integer, nil] in seconds
          # @return [String] e.g., "sync-1720280000"
          #
          # @example
          #   build_idempotency_scoped_key("sync", 10)
          #   # => "sync-1720280000"
          def build_idempotency_scoped_key(base_key, window)
            return base_key unless window

            rounded = Time.at((Time.current.to_f / window).floor * window).in_time_zone
            "#{base_key}-#{rounded.to_i}"
          end

          # Returns the default fields used to generate the instance idempotency key.
          # Override in your model if needed.
          #
          # @example
          #   def self.idempotency_key_fields
          #     [:payable_type, :payable_id, :amount]
          #   end
          def idempotency_key_fields
            [:id]
          end
        end

        # Executes a block under an advisory lock based on the instance's idempotency key.
        #
        # @param key [String, nil] optionally provide custom key
        # @param window [Integer, nil] optional time window (in seconds)
        # @param key_fields [Array<Symbol>, nil] override default fields used to build key
        #
        # @example
        #   entry.idempotency_lock! do
        #     entry.save!
        #   end
        #
        # @example With custom fields
        #   entry.idempotency_lock!(key_fields: [:payment_method_id, :amount], window: 5.seconds) do
        #     entry.process!
        #   end
        def idempotency_lock!(key: nil, window: nil, key_fields: nil, &block)
          key ||= generate_idempotency_key(key_fields: key_fields)
          raise ArgumentError, "Could not determine idempotency_key" unless key

          scoped_key = self.class.build_idempotency_scoped_key(key, window)

          self.idempotency_key ||= key if respond_to?(:idempotency_key=)
          if window && respond_to?(:idempotency_window=)
            self.idempotency_window ||= Time.at((Time.current.to_f / window).floor * window).in_time_zone
          end

          self.class.with_advisory_lock(scoped_key, timeout_seconds: 5, &block)
        end

        # Generates a unique SHA256 idempotency key based on selected fields of the instance
        #
        # @param key_fields [Array<Symbol>, nil] defaults to class method .idempotency_key_fields
        # @return [String, nil]
        #
        # @example
        #   entry.generate_idempotency_key
        #   # => "02c2fd7c9e1cb2..."
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