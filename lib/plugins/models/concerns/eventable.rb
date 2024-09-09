module Plugins
  module Models
    module Concerns
      module Eventable

        extend ActiveSupport::Concern

        included do
          class_attribute :event_base_name
          self.event_base_name = self.name
          [ :after_initialize, :after_find, :after_touch, :before_validation, :after_validation, :before_save, :after_save, :before_create, :after_create, :before_update, :after_update, :before_destroy, :after_destroy, :after_commit, :after_rollback ].each do  |callback|
            class_eval <<-CODE, __FILE__, __LINE__ + 1
              def _callback_event_#{callback}
                Plugins.config.events.instrument(type: self.class.event_base_name.demodulize.underscore.downcase + '.#{callback}', payload: self)
              end
            CODE
            send callback, "_callback_event_#{callback}".to_sym
          end
        end

      end
    end
  end
end