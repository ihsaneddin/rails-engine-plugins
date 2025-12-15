module Plugins
  module Decorators
    autoload :MethodAnnotations, "plugins/decorators/method_annotations"
    autoload :MethodDecorators, "plugins/decorators/method_decorators"
    autoload :Inheritables, "plugins/decorators/inheritables"
    autoload :SmartSend, "plugins/decorators/smart_send"
    autoload :ConfigBuilder, "plugins/decorators/config_builder"
    autoload :Registered, "plugins/decorators/registered"
    autoload :Traits, "plugins/decorators/traits"

    def self.method_annotations
      MethodAnnotations
    end

    def self.method_decorators
      MethodDecorators
    end

    def self.inheritables
      Inheritables
    end

    def self.config_builder
      ConfigBuilder
    end

    def self.smart_send
      SmartSend
    end

    def self.registered
      Registered
    end

    def self.traits
      Traits
    end

  end
end