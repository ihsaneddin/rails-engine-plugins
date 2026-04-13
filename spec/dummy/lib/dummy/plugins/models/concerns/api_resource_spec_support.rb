module Dummy
  module Plugins
    module Models
      module Concerns
        module ApiResourceSpecSupport
          def self.build_model(&block)
            Class.new do
              include ::Plugins::Models::Concerns::ApiResource

              class_eval(&block) if block
            end
          end
        end
      end
    end
  end
end
