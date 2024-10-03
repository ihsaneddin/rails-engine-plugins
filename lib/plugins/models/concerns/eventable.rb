module Plugins
  module Models
    module Concerns
      module Eventable

        extend ActiveSupport::Concern

        included do
          class_attribute :_instrumented_callbacks
          self._instrumented_callbacks = {}
          [ :before_validation, :after_validation, :before_save, :after_save, :before_create, :after_create, :before_update, :after_update, :before_destroy, :after_destroy ].each do  |kallback|
            class_eval <<-CODE, __FILE__, __LINE__ + 1
              def _callback_event_#{kallback}
                unless (self.class.instrumented_callbacks || []).include?('#{kallback.to_s}')
                  self.class.events_config.instrument(type: self.class.event_base_name.demodulize.underscore.downcase + '.#{kallback}', payload: self)
                  self.class.instrumented_callbacks= '#{kallback.to_s}'
                end
              end
            CODE
            send kallback, "_callback_event_#{kallback}".to_sym
          end
        end

        class_methods do

          def instrumented_callbacks
            self._instrumented_callbacks[self.name] ||= []
          end

          def instrumented_callbacks=(v)
            self._instrumented_callbacks[self.name] ||= []
            self._instrumented_callbacks[self.name] << v
          end

          def event_base_name
            self.name
          end

        end

      end
    end
  end
end