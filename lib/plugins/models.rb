module Plugins
  module Models
    autoload :Concerns, "plugins/models/concerns"
    autoload :FieldOptions, "plugins/models/field_options"

    extend ActiveSupport::Concern

    class_methods do
      def use_plugins_models(config= Plugins.config.events)
        class_attribute :events_config
        self.events_config= config
        include Plugins::Models::Concerns::Eventable
        include Plugins::Models::Concerns::ActsAsDefaultValue
      end
    end

  end
end