module Plugins
  module Models
    module Concerns
      autoload :Eventable, "plugins/models/concerns/eventable"
      autoload :Options, "plugins/models/concerns/options"
      autoload :ActsAsDefaultValue, "plugins/models/concerns/acts_as_default_value"
    end
  end
end