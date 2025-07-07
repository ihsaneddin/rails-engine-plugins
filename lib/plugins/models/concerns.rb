module Plugins
  module Models
    module Concerns
      autoload :Eventable, "plugins/models/concerns/eventable"
      autoload :Options, "plugins/models/concerns/options"
      autoload :ActsAsDefaultValue, "plugins/models/concerns/acts_as_default_value"
      autoload :Preferences, "plugins/models/concerns/preferences"
      autoload :CustomAttributes, "plugins/models/concerns/custom_attributes"
      autoload :Config, "plugins/models/concerns/config"
      autoload :PolymorphicAlternative, "plugins/models/concerns/polymorphic_alternative"
      autoload :IdempotencyLockable, "plugins/models/concerns/idempotency_lockable"
    end
  end
end