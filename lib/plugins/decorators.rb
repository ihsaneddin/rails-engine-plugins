module Plugins
  module Decorators
    autoload :MethodAnnotations, "plugins/decorators/method_annotations"
    autoload :MethodDecorators, "plugins/decorators/method_decorators"
    autoload :Inheritables, "plugins/decorators/inheritables"

    def self.method_annotations
      MethodAnnotations
    end

    def self.method_decorators
      MethodDecorators
    end

    def self.inheritables
      Inheritables
    end

  end
end