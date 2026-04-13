require File.expand_path("../../../../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../../../../lib/plugins/decorators/config_builder", __dir__)
require File.expand_path("../../../../../../lib/plugins/decorators/smart_send", __dir__)
require File.expand_path("../../../../../../lib/plugins/decorators/registered", __dir__)
require File.expand_path("../../../../../../lib/plugins/decorators/inheritables", __dir__)
require File.expand_path("../../../../../../lib/plugins/models/concerns/options", __dir__)
require File.expand_path("../../../../../../lib/plugins/decorators/method_annotations", __dir__)
require File.expand_path("../../../../../../lib/plugins/decorators/method_decorators", __dir__)
require File.expand_path("../../../../../../lib/plugins/decorators/traits", __dir__)

module Plugins
  def self.decorators
    Decorators
  end
end

module Dummy
  module PluginsDecoratorsSupport
    class ConfigBuilderHost
      extend ::Plugins::Decorators::ConfigBuilder
    end

    class SmartSendHost
      include ::Plugins::Decorators::SmartSend

      def positional(first, second = nil)
        [first, second]
      end

      def keyword(required:, optional: nil)
        [required, optional]
      end

      def mixed(first, second = nil, flag: nil, **rest)
        [first, second, flag, rest]
      end
    end

    module RegisteredRegistry
      include ::Plugins::Decorators::Registered
    end

    class InheritablesBase
      include ::Plugins::Decorators::Inheritables

      inheritable_class_attribute :settings, :tags
      self.settings = { nested: { enabled: true } }
      self.tags = Set.new(["plugins"])

      define_inheritable_singleton_method(:flag) { "base" }
    end

    class InheritablesChild < InheritablesBase; end

    class MethodAnnotationsHost
      include ::Plugins::Decorators::MethodAnnotations

      annotate_method :publish, event: :created, tags: %i[a b] do
        :ok
      end
    end

    class MethodDecoratorsHost
      include ::Plugins::Decorators::MethodDecorators

      define_method_decorator :audit do |method_name, original, *args, block, prefix:|
        [prefix, method_name, original.call(*args, &block)]
      end

      audit :perform, prefix: "tracked" do |value|
        value.upcase
      end
    end

    class MethodDecoratorsLateHost
      include ::Plugins::Decorators::MethodDecorators

      def perform(value)
        value * 2
      end

      define_method_decorator :audit do |_method_name, original, *args, block, suffix:|
        "#{original.call(*args, &block)}#{suffix}"
      end

      decorate_method :perform, with: :audit, suffix: "!"
    end

    module TraitsRegistry
      include ::Plugins::Decorators::Traits
      self.registered_classes = Set.new
    end

    class TraitsHost
      include ::Plugins::Decorators::Inheritables
    end

    module SearchableTrait
      def self.trait_name
        :searchable
      end
    end

    module MarkerTrait
      def self.trait_name
        :marker
      end

      module ClassMethods
        def marker
          "ok"
        end
      end
    end
  end
end
