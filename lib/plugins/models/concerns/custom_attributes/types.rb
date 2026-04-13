
module Plugins
  module Models
    module Concerns
      module CustomAttributes
        module Types

          mattr_accessor :registered_classes, :registered
          @@registered_classes = Set.new
          @@registered = false

          def self.register_class(klass)
            self.registered_classes << klass
          end

          def self.register_classes!
            unless self.registered
              self.registered_classes.each do |klass|
                ActiveModel::Type.register(klass.name.underscore.downcase.to_sym, klass)
              end
              self.registered = true
            end
          end

          autoload :Base, "plugins/models/concerns/custom_attributes/types/base"
          autoload :Geolocation, "plugins/models/concerns/custom_attributes/types/geolocation"
        end
      end
    end
  end
end