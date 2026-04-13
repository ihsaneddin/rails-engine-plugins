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
      autoload :RemoteCallbacks, "plugins/models/concerns/remote_callbacks"
      autoload :ApiResource, "plugins/models/concerns/api_resource"
      autoload :ThreadSafe, "plugins/models/concerns/thread_safe"
      autoload :TracksTransactionRoot, "plugins/models/concerns/tracks_transaction_root"
      autoload :AssociationHelpers, "plugins/models/concerns/association_helpers"
    end
  end
end