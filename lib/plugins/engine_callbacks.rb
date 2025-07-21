module Plugins
  module EngineCallbacks

    mattr_accessor :engine_callback_procs
    @@engine_callback_procs = {  }

    def self.add_callback engine_name, key, callback
      if @@engine_callback_procs[engine_name.to_sym].present?
        @@engine_callback_procs[engine_name.to_sym][key] << callback
      end
    end

    def self.extended base
      return unless base < ::Rails::Engine
      engine_name = base.engine_name
      @@engine_callback_procs[engine_name.to_sym] = { before_initialization: [], after_initialization: [], initializer: [] }

      base.config.before_initialize do |app|
        callbacks = ::Plugins::EngineCallbacks.engine_callback_procs[engine_name.to_sym]
        if callbacks.is_a?(Hash)
          before_initializations = callbacks[:before_initialization]
          if before_initializations.is_a?(Array)
            before_initializations.each do |callback|
              callback.call(app)
            end
          end
        end
      end
      base.initializer "#{engine_name}.initializer" do |app|
        callbacks = ::Plugins::EngineCallbacks.engine_callback_procs[engine_name.to_sym]
        if callbacks.is_a?(Hash)
          initializer = callbacks[:initializer]
          if initializer.is_a?(Array)
            initializer.each do |callback|
              callback.call(app)
            end
          end
        end
      end
      base.config.after_initialize do |app|
        callbacks = ::Plugins::EngineCallbacks.engine_callback_procs[engine_name.to_sym]
        if callbacks.is_a?(Hash)
          after_initializations = callbacks[:after_initialization]
          if after_initializations.is_a?(Array)
            after_initializations.each do |callback|
              callback.call(app)
            end
          end
        end
      end
    end

    def self.included base
      ::Plugins::EngineCallbacks.engine_callback_procs.each do |engine_name, value|
        ::Plugins::EngineCallbacks::ClassMethods.define_method("before_#{engine_name}_initialization") do |&block|
          callback = ::Plugins::EngineCallbacks::Callback.new( context: self, proc: block)
          ::Plugins::EngineCallbacks.add_callback(engine_name, :before_initialization, callback)
        end
        ::Plugins::EngineCallbacks::ClassMethods.define_method("#{engine_name}_initializer") do |&block|
          callback = ::Plugins::EngineCallbacks::Callback.new( context: self, proc: block)
          ::Plugins::EngineCallbacks.add_callback(engine_name, :initializer, callback)
        end
        ::Plugins::EngineCallbacks::ClassMethods.define_method("after_#{engine_name}_initialization") do |&block|
          callback = ::Plugins::EngineCallbacks::Callback.new( context: self, proc: block)
          ::Plugins::EngineCallbacks.add_callback(engine_name, :after_initialization, callback)
        end
      end
      base.extend ::Plugins::EngineCallbacks::ClassMethods
    end

    module ClassMethods

    end

    class Callback

      attr_accessor :context, :proc, :arguments

      def initialize context: nil, proc: nil, arguments: []
        @context = context
        @proc = proc
        @arguments = arguments
      end

      def call(*args)
        if @context
          @context.instance_exec(*args, &@proc)
        else
          @proc.call(*args)
        end
      end

    end

  end
end