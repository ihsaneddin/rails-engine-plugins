module Plugins
  module Models
    module Concerns
      # RemoteCallbacks enables one model (e.g., PaymentMethod) to register callbacks
      # that execute on another model (e.g., Entry) without modifying the target class directly.
      #
      # It supports all common ActiveRecord lifecycle callbacks and evaluates the callback
      # dynamically using a flexible configuration layer (Plugins::Models::Concerns::Config).
      #
      # Callbacks can be added via `callback_for`, specifying:
      #   - target class
      #   - callback name (e.g., :before_save)
      #   - a method or block to be evaluated
      #   - optional conditional execution via :if
      #
      # Example:
      #
      #   class PaymentMethod < ApplicationRecord
      #     include RemoteCallbacks
      #
      #     callback_for Entry, :before_validation, :mark_entry
      #     callback_for Entry, :validate, if: -> { enabled? } do, source: :pm, |entry|
      #       entry.errors.add(:base, "not valid")
      #     end
      #
      #     def mark_entry(entry)
      #       entry.flag = true
      #     end
      #   end
      #
      #   class Entry < ApplicationRecord
      #     include RemoteCallbacks
      #     belongs_to :payment_method
      #     def pm
      #       payment_method
      #     end
      #
      #   end
      #
      module RemoteCallbacks

        # Supported ActiveRecord lifecycle callbacks
        CALLBACKS = %i[
          before_validation after_validation
          before_save after_save
          before_create after_create
          before_update after_update
          before_destroy after_destroy
          validate
        ]

        def self.included(base)
          return if base.instance_variable_defined?(:@_remote_callbacks_loaded)
          base.include ::Plugins::Models::Concerns::Options::InheritableClassAttribute
          base.include ::Plugins.decorators.smart_send
          base.inheritable_class_attribute :_remote_callbacks, :_remote_callbacks_initialized
          base._remote_callbacks ||= []
          base.extend ClassMethods
          unless base._remote_callbacks_initialized
            base.setup_remote_callbacks!
            base._remote_callbacks_initialized = true
          end
          base.instance_variable_set(:@_remote_callbacks_loaded, true)
        end

        module ClassMethods

          # Registers a remote callback from the source class to the target class
          #
          # @param target [Class, String] Target model class or its name
          # @param callback_name [Symbol] Callback type (must be in CALLBACKS)
          # @param method_or_block [Symbol, Proc, nil] Optional method name or block
          # @param block [Proc] Optional block if method name not given
          #
          # Options:
          #   - :source [Symbol, Proc, UnboundMethod, Object]
          #       Value evaluated in context to get the source (default: current class name underscored)
          #   - :if [Boolean, Symbol, Proc] Whether to execute the callback
          #   - :exclusive [Boolean] If true, will run only if class matches target exactly
          #
          def callback_for(*args, &block)
            target         = args[0]
            callback_name  = args[1]
            opts = args.extract_options!
            args.compact!
            method_or_block = args.length > 2 ? args[2] : block

            raise ArgumentError, "Missing or invalid callback name" unless ::Plugins::Models::Concerns::RemoteCallbacks::CALLBACKS.include?(callback_name.to_sym)
            raise ArgumentError, "Must provide method or block" unless method_or_block

            target_class = target.is_a?(String) ? target.constantize : target

            unless target_class.include?(ActiveSupport::Callbacks)
              raise ArgumentError, "Target must include ActiveSupport::Callbacks"
            end

            unless target_class.include?(::Plugins::Models::Concerns::RemoteCallbacks)
              raise ArgumentError, "Target class must include RemoteCallbacks"
            end

            opts = {
              target_class: target_class.name,
              source: self.name.demodulize.underscore.to_sym,
              source_class: self.name,
              if: true,
              exclusive: true
            }.merge(opts)

            opts[:callback_name] = callback_name.to_s
            opts[:callback]      = method_or_block

            config = ::Plugins::Models::Concerns::Config.build(**opts)
            target_class._remote_callbacks << config.dup
            target_class.descendants.each do |subclass|
              subclass._remote_callbacks << config.dup
            end
          end

          # Injects ActiveRecord-style callbacks to evaluate remote callbacks
          def setup_remote_callbacks!
            ::Plugins::Models::Concerns::RemoteCallbacks::CALLBACKS.each do |kallback|
              send(kallback) do
                self.class._remote_callbacks.select { |cb| cb.callback_name == kallback.to_s }.each do |raw_cb|
                  # Split context into two parts: self config and source callback
                  self_cb   = raw_cb.dup.only_keys(:source, :if, :exclusive, :target_class)
                  self_cb.set_context(self)

                  # Skip unless condition is true
                  next unless self_cb.if

                  # Skip if exclusive mode and not exact class match
                  if self_cb.exclusive && self.class.name != self_cb.target_class
                    next
                  end

                  # Skip if no source
                  source = self_cb.source
                  next if source.nil?
                  source_cb = raw_cb.dup.only_keys(:callback, :source_class)
                  source = Array(source) unless source.is_a?(Enumerable)
                  source.select{|src| src.is_a?(::ActiveRecord::Base) && src.class <= source_cb.source_class.constantize }.uniq.each do |src|
                    source_cb.set_context(src)
                    source_cb.callback(self)
                  end
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
#       module RemoteCallbacks

#         CALLBACKS = %i[
#           before_validation after_validation before_save after_save
#           before_create after_create before_update after_update before_destroy after_destroy validate
#         ]

#         def self.included base
#           base.include ::Plugins::Models::Concerns::Options::InheritableClassAttribute
#           base.inheritable_class_attribute :_remote_callbacks, :_remote_callbacks_initialized
#           base._remote_callbacks ||= []
#           unless base._remote_callbacks_initialized
#             base.setup_remote_callbacks!
#             base._remote_callbacks_initialized = true
#           end
#           base.extend ClassMethods
#         end

#         module ClassMethods

#           def callback_for *args, &block
#             target = args[0]
#             callback_name = args[1]
#             method_or_block = args.length > 2 ? args[2] : block

#             raise ArgumentError, "Missing or invalid callback name" unless ::Plugins::Models::Concerns::RemoteCallbacks::CALLBACKS.include?(callback_name.to_sym)
#             raise ArgumentError, "Must provide method or block" unless method_or_block

#             target_class = target.is_a?(String) ? target.constantize : target
#             unless target_class.include?(ActiveSupport::Callbacks::ClassMethods)
#               raise ArgumentError, "Target must include #{ActiveSupport::Callbacks::ClassMethods.name}"
#             end

#             unless target_class.include?(::Plugins::Models::Concerns::RemoteCallbacks)
#               raise ArgumentError, "Target class must include be #{Plugins::Models::Concerns::RemoteCallbacks.name}"
#             end

#             opts = args.extract_options!
#             opts = { target_class: target_class.name, source: self.class.name.demodulize.underscore.to_sym, if: true, exclusive: false }.merge(opts)

#             opts[:callback] = method_or_block
#             opts[:callback_name]= callback_name.to_s

#             config = ::Plugins::Models::Concerns::Config.build(**opts)
#             target_class._remote_callbacks << config.dup
#           end

#           def setup_remote_callbacks!
#             ::Plugins::Models::Concerns::RemoteCallbacks::CALLBACKS.each do |kallback|
#               send(kallback) do
#                 self.class._remote_callbacks.select { |cb| cb.callback_name == kallback.to_s }.each do |raw_cb|
#                   self_cb   = raw_cb.dup.only_keys(:source, :if, :exclusive, :target_class)
#                   self_cb.set_context(self)

#                   next unless self_cb.if
#                   if self_cb.exclusive && self.class.name != self_cb.target_class
#                     next
#                   end
#                   next if self_cb.source.nil?

#                   source_cb = raw_cb.dup.only_keys(:callback)
#                   source_cb.set_context(self_cb.source)
#                   source_cb.callback(self)
#                 end
#               end
#             end
#           end

#         end

#       end
#     end
#   end
# end

