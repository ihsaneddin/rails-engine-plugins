require 'options_model'

module Plugins
  module Configuration
    module Callbacks

      class Callback
        attr_reader :name, :namespace, :action, :options

        def initialize(name, _namespace: [], **_options, &_block)
          @name = name
          @namespace = _namespace
          options = _options
          @options = options
          @options[:override] ||= true
          @action = options[:action]
          @class = options[:class] || default_class
          @block = _block
        end

        def default_class
          "base"
        end

        def call(context, *args)
          context.instance_exec(*args, &@block)
        end

        delegate :hash, to: :instance_values

        def ==(other)
          return false unless other.is_a?(Plugins::Configuration::Callbacks::Callback)

          instance_values == other.instance_values
        end

        def class_name
          _namespace = @namespace.dup
          if @class.present?
            _namespace << @class
          end
          base = options[:base] ? "#{options[:base]}::" : ""
          "#{base}#{_namespace.map{|n| n.to_s.camelize }.join("::")}"
        end

        alias eql? ==
      end

      class ComputedCallbacks
        delegate :each, :map, :filter,  :to_a, :to_ary, to: :@callbacks

        def initialize(callbacks = [])
          @callbacks = [].concat callbacks.to_a
          regroup!
        end

        def concat(callbacks)
          @callbacks.concat callbacks
          regroup!

          self
        end

        def call(context, *args)
          @callbacks.each do |callback|
            callback.call(context, *args)
          end

          self
        end

        private

          def regroup!
            @callbacks.uniq!
          end
      end

      class CallbackSet < OptionsModel::Base

        BLOCK_CALLBACKS = []
        CALLBACKS = [] + BLOCK_CALLBACKS

        def permitted_callback_names
          attributes.select { |_, v| v }.keys
        end

        def computed_callbacks(include_nesting: true)
          callbacks = self.class.registered_callbacks.values
          callbacks.concat self.class.nested_classes.values.map{|v| v.new.computed_callbacks}.flatten! if include_nesting && self.class.nested_classes.any?

          ComputedCallbacks.new(callbacks)
        end

        class << self

          def use_relative_model_naming?
            true
          end

          def callback_class
            Callback
          end

          def callback_class=(klass)
            raise ArgumentError, "#{klass} should be sub-class of #{Callback}." unless klass && klass < Callback

            @callback_class = klass
          end

          def draw_callbacks(constraints = {}, &block)
            raise ArgumentError, "must provide a block" unless block_given?

            Mapper.new(self, constraints).instance_exec(&block)

            self
          end

          def registered_callbacks
            @registered_callbacks ||= ActiveSupport::HashWithIndifferentAccess.new
          end

          def register_callback(name, options = {}, &block)
            raise ArgumentError, "`name` can't be blank" if name.blank?
            raise ArgumentError, "name #{name} is not included in the list" unless permitted_callback_names.include?(name.to_s)

            registered_callbacks[name] = callback_class.new name, **options, &block
          end

          def permitted_callback_names
            self::CALLBACKS
          end

          def required_block_callback_names
            self::BLOCK_CALLBACKS
          end

          PERMITTED_ATTRIBUTE_CLASSES = [Symbol].freeze

          def permitted_attribute_classes
            PERMITTED_ATTRIBUTE_CLASSES
          end
        end
      end

      class Mapper

        #CALLBACKS = ['before', 'after_fetch_resource', 'collection_scope', 'after', 'use_friendly_id?', 'resource_id_key', 'resource_id_field', 'use_pagination?']

        def initialize(callbackset, constraints = {})
          @constraints = constraints
          @constraints[:_namespace] ||= []
          @callbackset = callbackset
        end

        def callback(name, *args, &block)
          options = args.extract_options!
          raise ArgumentError, "must provide a block" if args.blank? && !block_given?
          raise ArgumentError, "block is required for #{name} callback" if @callbackset.required_block_callback_names.include?(name.to_s) && !block_given?
          if args[0].present?
            prc = Proc.new{ args[0] }
            @callbackset.register_callback name, @constraints.merge(options), &prc
          else
            @callbackset.register_callback name, @constraints.merge(options), &block
          end
          self
        end

        def namespace(name, constraints = {}, &block)
          raise ArgumentError, "`name` can't be blank" if name.blank?
          raise ArgumentError, "must provide a block" unless block_given?

          constraints[:_namespace] ||= @constraints[:_namespace].dup
          constraints[:_namespace] << name

          sub_callback_set_class =
            if @callbackset.nested_classes.key?(name)
              @callbackset.nested_classes[name]
            else
              klass_name = constraints[:_namespace].map { |n| n.to_s.classify }.join("::")
              klass = @callbackset.derive klass_name
              @callbackset.embeds_one(name, anonymous_class: klass)

              klass
            end
          sub_callback_set_class.draw_callbacks(@constraints.merge(constraints), &block)

          self
        end

        def endpoint(name, constraints = {}, &block)
          raise ArgumentError, "`name` can't be blank" if name.blank?
          raise ArgumentError, "must provide a block" unless block_given?

          constraints[:_namespace] ||= @constraints[:_namespace].dup

          sub_callback_set_class =
            if @callbackset.nested_classes.key?(name)
              @callbackset.nested_classes[name]
            else
              klass_name = constraints[:_namespace].map { |n| n.to_s.classify }.join("::")
              klass = @callbackset.derive klass_name
              @callbackset.embeds_one(name, anonymous_class: klass)

              klass
            end
          constraints[:class] = name
          sub_callback_set_class.draw_callbacks(@constraints.merge(constraints), &block)

          self
        end

        alias_method :channel, :endpoint

      end

      module Attacher

        def self.included base
          base.class_attribute :callback_applied
          base.callback_applied = {}
          base.extend ClassMethods
          base.class_attribute :callback_set
          base.callback_set = Plugins::Configuration::Callbacks::CallbackSet
        end

        module ClassMethods

          def inherited(subclass)
            self.apply_kallbacks!
            TracePoint.trace(:end) do |t|
              if subclass == t.self
                subclass.apply_kallbacks!
                t.disable
              end
            end
            super
          end

          def apply_kallbacks!
            unless self.callback_applied[self.name]
              kallbacks.each do |callback|
                callback.call(self)
              end
              self.callback_applied[self.name] = true
            end
          end

          def kallbacks
            _kallbacks = callback_set_class.new.computed_callbacks.filter do |callback|
              callback.class_name == name
            end
            _kallbacks
          end

          def callback_set_class
            self.callback_set
          end

        end

      end

    end
  end
end