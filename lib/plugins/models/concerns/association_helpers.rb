module Plugins
  module Models
    module Concerns
      module AssociationHelpers

        extend ActiveSupport::Concern

        def include_existing_relation(relation_name)
          return unless respond_to?(relation_name)

          rel = association(relation_name)
          existing = rel.scope.to_a
          rel.target |= existing
        end

      end
    end
  end
end