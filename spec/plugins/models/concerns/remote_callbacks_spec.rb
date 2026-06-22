require "spec_helper"
require "active_record"
require "active_support/all"
require File.expand_path("../../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../../lib/plugins/decorators/smart_send", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/config", __dir__)
require File.expand_path("../../../../lib/plugins/models/concerns/options", __dir__)

module Plugins
  def self.decorators
    Decorators
  end
end

require File.expand_path("../../../../lib/plugins/models/concerns/remote_callbacks", __dir__)

RSpec.describe Plugins::Models::Concerns::RemoteCallbacks do
  before(:context) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define do
      create_table :remote_callback_sources, force: true do |t|
        t.string :name
        t.timestamps
      end

      create_table :remote_callback_targets, force: true do |t|
        t.references :remote_callback_source, null: false
        t.string :status
        t.timestamps
      end
    end
  end

  after(:context) do
    ActiveRecord::Schema.define do
      drop_table :remote_callback_targets, if_exists: true
      drop_table :remote_callback_sources, if_exists: true
    end
  end

  before do
    stub_const("RemoteCallbackSource", Class.new(ActiveRecord::Base) do
      self.table_name = "remote_callback_sources"

      include Plugins::Models::Concerns::RemoteCallbacks

      has_many :remote_callback_targets

      def mark_committed(target)
        target.update_column(:status, "committed")
      end
    end)

    stub_const("RemoteCallbackTarget", Class.new(ActiveRecord::Base) do
      self.table_name = "remote_callback_targets"

      include Plugins::Models::Concerns::RemoteCallbacks

      belongs_to :remote_callback_source
    end)
  end

  it "runs callbacks registered for after_commit" do
    RemoteCallbackSource.callback_for(
      RemoteCallbackTarget,
      :after_commit,
      :mark_committed
    )

    source = RemoteCallbackSource.create!(name: "source")
    target = RemoteCallbackTarget.create!(
      remote_callback_source: source,
      status: "pending"
    )

    expect(target.reload.status).to eq("committed")
  end
end
