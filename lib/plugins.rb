require "plugins/version"
require "plugins/engine"
require 'store_model'
require 'ransack'
require 'omnes'

module Plugins
  autoload :Configuration, "plugins/configuration"
  autoload :Controllers, "plugins/controllers"
  autoload :Models, "plugins/models"
  autoload :Presenters, "plugins/presenters"
  autoload :EngineCallbacks, "plugins/engine_callbacks"
  autoload :Errors, "plugins/errors"
  autoload :Decorators, 'plugins/decorators'

  mattr_accessor :configuration
  @@configuration = Configuration

  def self.config
    @@configuration
  end

  def self.setup &block
    config.setup &block
  end

  def self.decorators
    Decorators
  end

end

require "plugins/railtie"
require 'plugins/hooks'