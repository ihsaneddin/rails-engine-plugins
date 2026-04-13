require "spec_helper"
require "active_support/all"
require File.expand_path("../../lib/plugins/engine_callbacks", __dir__)

unless defined?(Rails)
  module Rails
    class Engine; end
  end
end

RSpec.describe Plugins::EngineCallbacks do
  before do
    described_class.engine_callback_procs = {}
  end

  it "calls callbacks with context when wrapped in Callback" do
    context = Class.new do
      class << self
        attr_accessor :received
      end
    end

    callback = described_class::Callback.new(context: context, proc: ->(value) { self.received = value })
    callback.call("ok")

    expect(context.received).to eq("ok")
  end

  it "adds callbacks into the registered engine callback bucket" do
    described_class.engine_callback_procs[:plugins] = { before_initialization: [], after_initialization: [], initializer: [] }
    callback = described_class::Callback.new(proc: -> {})

    described_class.add_callback(:plugins, :initializer, callback)

    expect(described_class.engine_callback_procs[:plugins][:initializer]).to include(callback)
  end

  it "defines lifecycle registration methods when included after an engine was extended" do
    config = Class.new do
      attr_reader :before_blocks, :after_blocks

      def initialize
        @before_blocks = []
        @after_blocks = []
      end

      def before_initialize(&block)
        @before_blocks << block
      end

      def after_initialize(&block)
        @after_blocks << block
      end
    end.new

    engine_class = Class.new(Rails::Engine) do
      def self.engine_name
        "fake_engine"
      end

      def self.config
        @config ||= config_object
      end

      def self.config_object=(value)
        @config_object = value
      end

      def self.config_object
        @config_object
      end

      def self.initializer(_name, &block)
        (@initializers ||= []) << block
      end
    end

    engine_class.config_object = config
    described_class.extended(engine_class)

    host = Module.new do
      include Plugins::EngineCallbacks
    end

    marker = []
    host.before_fake_engine_initialization { |app| marker << [:before, app] }
    host.fake_engine_initializer { |app| marker << [:init, app] }
    host.after_fake_engine_initialization { |app| marker << [:after, app] }

    app = Object.new
    config.before_blocks.each { |blk| blk.call(app) }
    engine_class.instance_variable_get(:@initializers).each { |blk| blk.call(app) }
    config.after_blocks.each { |blk| blk.call(app) }

    expect(marker).to eq([[:before, app], [:init, app], [:after, app]])
  end
end
