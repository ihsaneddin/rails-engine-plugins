module Plugins
  module Grape
    module Presenters
      class Generic < Base

        expose :details, merge: true

        private

          def details
            object.as_json
          end

      end
    end
  end
end