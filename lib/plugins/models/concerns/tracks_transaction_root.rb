module Plugins
  module Models
    module Concerns
      module TracksTransactionRoot
        extend ActiveSupport::Concern

        included do
          around_save :track_transaction_root
        end

        class_methods do
          def transaction_stack_key
            :"__transaction_root_stack_for_#{name.underscore}"
          end

          def current_transaction_root
            (Thread.current[transaction_stack_key] ||= []).last
          end
          def transaction_root_for(obj)
            klass = obj.is_a?(Class) ? obj : obj.class
            key = :"__transaction_root_stack_for_#{klass.base_class.name.underscore}"
            (Thread.current[key] ||= []).last
          end
        end

        def transaction_root_for(obj)
          self.class.transaction_root_for(obj)
        end

        # Returns true if this object is currently being saved as part of a nested save
        def saved_by_nested_save?
          transaction_root_for(self) != self
        end

        # Returns true if this object is being saved as part of a save triggered by a specific class or object
        def saved_by_nested_save_from?(klass_or_instance)
          transaction_root_for(klass_or_instance).present?
        end

        private

        def track_transaction_root
          key = self.class.transaction_stack_key
          stack = Thread.current[key] ||= []
          root_pushed = false

          unless stack.any?
            stack.push(self)
            root_pushed = true
          end

          yield
        ensure
          stack.pop if root_pushed
        end
      end
    end
  end
end