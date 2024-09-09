module Plugins
  module Configuration

    autoload :Events, "plugins/configuration/events"
    autoload :Callbacks, "plugins/configuration/callbacks"
    autoload :Api, "plugins/configuration/api"

    mattr_accessor :events
    @@events = Plugins::Configuration::Events

    mattr_accessor :_api
    @@api = Plugins::Configuration::Api

    mattr_accessor :_engine_namespace
    @@_engine_namespace= nil

    def engine_namespace=(namespace)
      @@_engine_namespacee= namespace
    end

    def self.setup &block
      block.arity.zero? ? instance_eval(&block) : yield(self)
    end

    def self.api &block
      if block_given?
        @@_api.setup(&block)
      else
        @@_api
      end
    end

  end
end