module Plugins
  module Models
    module Extensions
      module Association

        module HasManyStiBuildersPatch
          def self.call(sti_type)
            Module.new do
              define_method(:build) do |attributes = {}, &block|
                super(attributes.merge(type: sti_type), &block)
              end

              define_method(:new) do |attributes = {}, &block|
                build(attributes, &block)
              end

              define_method(:create) do |attributes = {}, &block|
                super(attributes.merge(type: sti_type), &block)
              end

              define_method(:create!) do |attributes = {}, &block|
                super(attributes.merge(type: sti_type), &block)
              end
            end
          end
        end

      end
    end
  end
end