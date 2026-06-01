require "spec_helper"
require "active_support/all"
require File.expand_path("../../../../lib/plugins/models/concerns/idempotency_lockable", __dir__)

RSpec.describe Plugins::Models::Concerns::IdempotencyLockable do
  let(:lockable_class) do
    Class.new do
      attr_accessor :idempotency_key, :attributes

      def self.name
        "TestLockable"
      end

      def self.with_advisory_lock(*args, &block)
        advisory_lock_calls << args
        block.call if block
      end

      def self.advisory_lock_calls
        @advisory_lock_calls ||= []
      end

      def self.transaction(&block)
        @transaction_called = true
        block.call
      end

      def self.transaction_called?
        @transaction_called == true
      end

      include Plugins::Models::Concerns::IdempotencyLockable

      def initialize
        self.attributes = { "id" => 42 }
      end
    end
  end

  it "uses transaction-level advisory locks inside a transaction by default" do
    lockable = lockable_class.new

    lockable.idempotency_lock!(timeout: 9) { :done }

    expect(lockable_class).to be_transaction_called
    expect(lockable_class.advisory_lock_calls.last).to eq(
      ["093cc715305d152b24fd15f301fad90eca65356e4f70b4765034aa74ee424646", { timeout_seconds: 9, transaction: true }]
    )
  end

  it "uses a session-level advisory lock when transaction is disabled" do
    lockable = lockable_class.new

    lockable.idempotency_lock!(timeout: 3, transaction: false) { :done }

    expect(lockable_class).not_to be_transaction_called
    expect(lockable_class.advisory_lock_calls.last).to eq(
      ["093cc715305d152b24fd15f301fad90eca65356e4f70b4765034aa74ee424646", { timeout_seconds: 3, transaction: false }]
    )
  end
end
