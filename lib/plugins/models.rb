module Plugins
  module Models
    autoload :Concerns, "plugins/models/concerns"
    autoload :FieldOptions, "plugins/models/field_options"

    extend ActiveSupport::Concern

    def self.use_plugins_models
      include Plugins::Models::Concerns::Eventable
      include Plugins::Models::Concerns::ActsAsDefaultValue
    end

  end
end