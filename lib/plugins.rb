require "plugins/version"
require "plugins/engine"

module Plugins
  autoload :Configuration, "plugins/configuration"
  autoload :Controllers, "plugins/controllers"
  autoload :Models, "plugins/models"
  autoload :Presenters, "plugins/presenters"
  autoload :Errors, "plugins/errors"
end

require "plugins/railtie"