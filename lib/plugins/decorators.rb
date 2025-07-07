module Plugins
  module Decorators
    autoload :MethodAnnotations, "plugins/decorators/method_annotations"
    autoload :MethodDecorators, "plugins/decorators/method_decorators"

    def self.method_annotations
      MethodAnnotations
    end

    def self.method_decorators
      MethodDecorators
    end

  end
end