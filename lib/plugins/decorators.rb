module Plugins
  module Decorators
    autoload :MethodAnnotations, "plugins/decorators/method_annotations"
    autoload :MethodDecorators, "plugins/decorators/method_decorators"
    autoload :Inheritables, "plugins/decorators/inheritables"
    autoload :SmartSend, "plugins/decorators/smart_send"
    autoload :ConfigBuilder, "plugins/decorators/config_builder"

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

  end
end