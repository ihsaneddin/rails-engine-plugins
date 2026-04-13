require "set"
require "concurrent/map"

module Plugins
  module Models
    module Concerns
      # == Plugins::Models::Concerns::ThreadSafe
      #
      # A reusable concurrency module for guarding critical sections using thread-local
      # or mutex-based strategies. Ensures a block of code is executed only once
      # per thread or safely synchronized across threads.
      #
      # === Include in your class
      #   class MyWorker
      #     include Plugins::Models::Concerns::ThreadSafe
      #
      #     def run
      #       thread_safe("my-task-key") do
      #         do_work
      #       end
      #     end
      #   end
      #
      # === Class-level usage
      #   Plugins::Models::Concerns::ThreadSafe.with_thread_guard(key: "import-task") do
      #     ImportService.run
      #   end
      #
      # === Use with mutex strategy
      #   Plugins::Models::Concerns::ThreadSafe.with_thread_guard(
      #     key: "batch-task",
      #     strategy: :mutex,
      #     on_reentry: :raise
      #   ) do
      #     CriticalSection.run!
      #   end
      #
      # === Integration with other systems
      # Combine with idempotency locks, DB transactions, or other locking systems
      # for maximum safety.
      #
      # === Options:
      # - +key+: Unique key per critical section.
      # - +strategy+: :thread (default) or :mutex
      # - +on_reentry+: :skip (default), :raise
      #
      # === Related:
      # - IdempotencyLockable
      #
      module ThreadSafe
        THREAD_KEY = :__thread_safe_keys__

        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
          # Executes a block under thread-safe or mutex-safe guard
          #
          # @param key [String] Unique lock key
          # @param strategy [Symbol] :thread (default) or :mutex
          # @param on_reentry [Symbol] :skip (default), or :raise
          #
          # @example Default thread-safe usage
          #   with_thread_guard(key: "sync") { do_work }
          #
          # @example Using mutex strategy
          #   with_thread_guard(key: "sync", strategy: :mutex) { sync_data }
          def with_thread_guard(key:, strategy: :thread, on_reentry: :skip, &block)
            raise ArgumentError, "Missing block" unless block_given?

            case strategy
            when :thread then perform_thread_guard(key, on_reentry, &block)
            when :mutex  then perform_mutex_guard(key, on_reentry, &block)
            else raise ArgumentError, "Unknown strategy: #{strategy.inspect}"
            end
          end

          # Returns true if the given key is currently thread-guarded
          #
          # @param key [String]
          # @return [Boolean]
          def thread_guarded?(key)
            Thread.current[THREAD_KEY]&.include?(key.to_s)
          end

          private

          def perform_thread_guard(key, on_reentry, &block)
            key = key.to_s
            Thread.current[THREAD_KEY] ||= Set.new

            if Thread.current[THREAD_KEY].include?(key)
              case on_reentry
              when :raise then raise "Already guarded for key: #{key}"
              when :skip  then return
              else raise ArgumentError, "Invalid :on_reentry option: #{on_reentry.inspect}"
              end
            end

            begin
              Thread.current[THREAD_KEY] << key
              yield
            ensure
              Thread.current[THREAD_KEY].delete(key)
            end
          end

          def perform_mutex_guard(key, on_reentry, &block)
            key = key.to_s
            @__mutex_pool ||= Concurrent::Map.new
            mutex = @__mutex_pool.compute_if_absent(key) { Mutex.new }

            if mutex.locked?
              case on_reentry
              when :raise then raise "Mutex already locked for key: #{key}"
              when :skip  then return
              else raise ArgumentError, "Invalid :on_reentry option: #{on_reentry.inspect}"
              end
            end

            mutex.synchronize(&block)
          end
        end

        # Instance-level wrapper around class method
        #
        # @example
        #   thread_safe("entry-process") { do_work }
        def with_thread_guard(**opts, &block)
          self.class.with_thread_guard(**opts, &block)
        end

        # Checks if thread guard is active for this key
        def thread_guarded?(key)
          self.class.thread_guarded?(key)
        end

        # Shorthand instance method for thread-based safe execution
        #
        # @example
        #   thread_safe("user-cache") { fetch_data }
        def thread_safe(key, &block)
          with_thread_guard(key: key, strategy: :thread, on_reentry: :skip, &block)
        end
      end
    end
  end
end
