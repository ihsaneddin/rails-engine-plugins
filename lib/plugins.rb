require "plugins/version"
require "plugins/engine"

module Plugins
  autoload :Configuration, "plugins/configuration"
  autoload :Controllers, "plugins/controllers"
  autoload :Models, "plugins/models"
  autoload :Presenters, "plugins/presenters"
  autoload :Errors, "plugins/errors"

  mattr_accessor :configuration
  @@configuration = Configuration

  def self.config
    @@configuration
  end

  def self.setup &block
    config.setup &block
  end

end

require "plugins/railtie"
require 'plugins/hooks'