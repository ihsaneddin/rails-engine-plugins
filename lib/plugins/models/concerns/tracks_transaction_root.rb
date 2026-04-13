module Plugins
  module Models
    module Concerns
      module TracksTransactionRoot
        extend ActiveSupport::Concern

        included do
          around_save :track_transaction_root
          before_commit :track_transaction_root_before_commit
          after_commit :track_transaction_root_after_commit
          after_rollback :track_transaction_root_after_commit
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
            key = :"__transaction_root_stack_for_#{klass.name.underscore}"
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

        # Returns true if this object is being committed as part of a nested commit
        def committed_by_nested_commit?
          transaction_root_for(self) != self
        end

        # Returns true if this object is being saved as part of a save triggered by a specific class or object
        def saved_by_nested_save_from?(klass_or_instance)
          transaction_root_for(klass_or_instance).present?
        end

        # Returns true if this object is committing as part of a commit triggered by a specific class or object
        def committed_by_nested_commit_from?(klass_or_instance)
          transaction_root_for(klass_or_instance).present?
        end

        private

        def track_transaction_root
          root_pushed = push_transaction_root_if_needed
          yield
        ensure
          pop_transaction_root if root_pushed
        end

        # Rails has no around_commit, so pair before/after hooks to mimic it
        def track_transaction_root_before_commit
          @transaction_root_pushed_for_commit = push_transaction_root_if_needed
        end

        def track_transaction_root_after_commit
          pop_transaction_root if @transaction_root_pushed_for_commit
          @transaction_root_pushed_for_commit = false
        end

        def push_transaction_root_if_needed
          stack = Thread.current[self.class.transaction_stack_key] ||= []
          return false if stack.any?

          stack.push(self)
          true
        end

        def pop_transaction_root
          stack = Thread.current[self.class.transaction_stack_key] ||= []
          stack.pop
        end
      end
    end
  end
end

# module Plugins
#   module Models
#     module Concerns
#       module TracksTransactionRoot
#         extend ActiveSupport::Concern

#         included do
#           around_save :track_transaction_root
#         end

#         class_methods do
#           def transaction_stack_key
#             :"__transaction_root_stack_for_#{name.underscore}"
#           end

#           def current_transaction_root
#             (Thread.current[transaction_stack_key] ||= []).last
#           end
#           def transaction_root_for(obj)
#             klass = obj.is_a?(Class) ? obj : obj.class
#             key = :"__transaction_root_stack_for_#{klass.name.underscore}"
#             (Thread.current[key] ||= []).last
#           end
#         end

#         def transaction_root_for(obj)
#           self.class.transaction_root_for(obj)
#         end

#         # Returns true if this object is currently being saved as part of a nested save
#         def saved_by_nested_save?
#           transaction_root_for(self) != self
#         end

#         # Returns true if this object is being saved as part of a save triggered by a specific class or object
#         def saved_by_nested_save_from?(klass_or_instance)
#           transaction_root_for(klass_or_instance).present?
#         end

#         private

#         def track_transaction_root
#           key = self.class.transaction_stack_key
#           stack = Thread.current[key] ||= []
#           root_pushed = false

#           unless stack.any?
#             stack.push(self)
#             root_pushed = true
#           end

#           yield
#         ensure
#           stack.pop if root_pushed
#         end
#       end
#     end
#   end
# end
