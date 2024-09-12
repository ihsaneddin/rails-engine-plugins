module Plugins
  module Models
    autoload :Concerns, "plugins/models/concerns"
    autoload :FieldOptions, "plugins/models/field_options"

    extend ActiveSupport::Concern

    class_methods do
      def use_plugins_models
        include Plugins::Models::Concerns::Eventable
        include Plugins::Models::Concerns::ActsAsDefaultValue
      end
    end


  end
end