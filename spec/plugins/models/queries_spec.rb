require "spec_helper"
require "active_support/all"
require "securerandom"
require "set"
require File.expand_path("../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../lib/plugins/decorators/smart_send", __dir__)
require File.expand_path("../../../lib/plugins/decorators/inheritables", __dir__)
require File.expand_path("../../../lib/plugins/models/concerns/options", __dir__)
require File.expand_path("../../../lib/plugins/decorators/method_annotations", __dir__)
require File.expand_path("../../../lib/plugins/decorators/method_decorators", __dir__)
require File.expand_path("../../../lib/plugins/decorators/registered", __dir__)
module Plugins
  def self.decorators
    Decorators
  end
end

require File.expand_path("../../../lib/plugins/models/queries", __dir__)

RSpec.describe Plugins::Models::Queries::Object do
  it "registers query classes and maps explicit query methods" do
    query_class = Class.new do
      def self.name
        "EventSearch"
      end

      include Plugins::Models::Queries::Object

      query_object { |query| query.is_a?(Array) }

      def active
        []
      end

      define_query :active
    end

    expect(described_class.registered_classes).to include(query_class)
    expect(query_class.query_methods).to eq(active: "event_search_active")
    expect(query_class.new.active).to eq([])
  end
end
