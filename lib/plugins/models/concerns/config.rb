module Plugins
  module Models
    module Concerns
      class Config
        class Collection < Config
          include Enumerable
          attr_accessor :template, :order

          def initialize(values: {})
            @template = values.dup
            @order    = []
            super(values: {})
          end

          def allow_new_entries?
            @_setter_mode
          end

          def each(resolved: true)
            return to_enum(:each, resolved: resolved) unless block_given?
            (order || []).each do |key|
              entry = values[key]
              next unless entry
              resolved_value = resolved ? resolve_entry(key, entry) : nil
              yield key, entry, resolved_value
            end
          end

          def to_a(resolved: true)
            (order || []).map do |k|
              entry = values[k]
              resolved ? resolve_entry(k, entry) : entry
            end.compact
          end

          def [](name, resolved: false)
            entry = values[name.to_sym]
            return unless entry
            resolved ? resolve_entry(name, entry) : entry
          end

          def method_missing(name, *args, &block)
            key_str = name.to_s

            if key_str.end_with?("=")
              key   = key_str.chomp("=").to_sym
              entry = values[key] || (allow_new_entries? ? ensure_entry(key) : super)
              entry.set(:value, args.first)
              return entry
            end

            key = name.to_sym
            if values.key?(key)
              entry = values[key]
              if block
               opts = args.extract_options!
                if opts.blank?
                  entry.start_setter_mode!
                  entry.instance_exec(*args, &block)
                  entry.end_setter_mode!
                else
                  entry.setup(**opts)
                  entry.set(:value,block)
                end
                return entry
              else
                if args.length > 0
                  val = args.first
                  entry.set(:value, val)
                end
              end
              # if args.length > 0
              #   val = args.first
              #   entry.set(:value, val)
              # end
              # if block
              #   entry.start_setter_mode!
              #   entry.instance_exec(*args, &block)
              #   entry.end_setter_mode!
              # end
              return entry if block || args.length > 0
              entry.get(:value)
            elsif allow_new_entries?
              entry = ensure_entry(key)
              if block
                opts = args.extract_options!
                if opts.blank?
                  entry.start_setter_mode!
                  entry.instance_exec(*args, &block)
                  entry.end_setter_mode!
                else
                  entry.setup(**opts)
                  entry.set(:value,block)
                end
              else
                if args.length > 0
                  val = args.first
                  entry.set(:value, val)
                end
              end
              # if args.length > 0
              #   val = args.first
              #   entry.set(:value, val)
              # end
              # if block
              #   entry.start_setter_mode!
              #   entry.instance_exec(*args, &block)
              #   entry.end_setter_mode!
              # end
              entry
            else
              super
            end
          end

          def respond_to_missing?(name, include_private = false)
            key = name.to_s.chomp("=").to_sym
            values.key?(key) || allow_new_entries? || super
          end

          def set_context(ctx)
            @_context = ctx
            values.each_value { |cfg| cfg.set_context(ctx) }
          end

          def dup
            copy = super
            copy.instance_variable_set(:@template, @template.dup)
            copy.instance_variable_set(:@order, @order.dup)
            copy.instance_variable_set(:@_values, values.transform_values { |cfg| cfg.dup })
            copy
          end

          private

          def ensure_entry(key)
            values[key] ||= begin
              cfg = Config.new(values: (template || {}).merge(value: (template && template[:value]) || key))
              cfg.dynamic_keys!               # allow value/metrics/etc.
              cfg.set_context(@_context)
              order << key
              cfg
            end
          end

          def resolve_entry(key, entry)
            entry&.value || (@_context && @_context.public_send(key))
          end
        end


        attr_reader :_values, :_context, :_setter_mode, :_supress, :_dynamic_keys

        INVALID_KEYS = %w[
            setup
            reset
            add
            exists?
            to_h
            values
            keys
            eligible_key?
            start_setter_mode!
            end_setter_mode!
            supress!
            unsupress!
            dynamic_keys!
            with_dynamic_keys
            static_keys!
            initialize
            with_context
            set_context
            evaluate_with_context
            send_with_context
            set
            set!
            get
            method_missing
            []
            build
            valid_key?
            valid_keys?
            remove_key
            remove_keys
            only_key
            only_keys
            config
          ]

        module InheritableClassAttribute

          extend ActiveSupport::Concern

          class_methods do

            def deep_copy(value, opts = {})
              value = super(value, opts)
              if value.is_a?(::Plugins::Models::Concerns::Config)
                value.set_context(opts[:subclass])
              end
              value
            end

          end

        end

        def self.setup(base, config_name, opts = {}, default_opts = {}, **kwargs, &block)

          _config_name = "_#{config_name}"

          if base.respond_to?(_config_name)
            default_opts = default_opts.merge(base.send(_config_name).values.dup)
            opts = default_opts.merge(opts.slice(*default_opts.keys))
            base.send(_config_name).instance_variable_set(:@_values, opts.dup)
            base.send("#{_config_name}=", base.send(_config_name).dup)
            if block_given?
              base.send(_config_name).setup(**opts, &block)
            end
            base.send(_config_name).set_context(base)
          else
            base.include ::Plugins.decorators.inheritables.singleton_methods
            base.include ::Plugins.decorators.smart_send
            base.inheritable_class_attribute _config_name.to_sym

            opts = default_opts.merge(opts.slice(*default_opts.keys))
            config = new(values: opts)
            base.send("#{_config_name}=", config)
            base.send(_config_name).set_context(base)
            if block_given?
              base.send(_config_name).setup(&block)
            end
            instance_config_var = :"@__cached_config_#{config_name}"

            base.define_inheritable_singleton_method(config_name) { send(_config_name) }
            base.define_method(config_name) do
              instance_variable_get(instance_config_var) || instance_variable_set(instance_config_var, begin
                dup = self.class.send(_config_name).dup
                dup.set_context(self)
                dup
              end)
            end

            # base.singleton_class.define_method(:inherited) do |subclass|
            #   super(subclass)
            #   subclass_config = send(_config_name)
            #   subclass_config.set_context(subclass)
            # end

            base.include(::Plugins::Models::Concerns::Config::InheritableClassAttribute)

            method_prefix = kwargs[:method_prefix] || config_name

            opts.keys.each do |key|
              base.define_method("#{method_prefix}_#{key}") do |*args|
                self.send(config_name).get(key, *args)
              end
              base.define_inheritable_singleton_method("#{method_prefix}_#{key}") do |*args|
                self.send(config_name).get(key, *args)
              end
            end
          end

          base.send(_config_name)
        end

        def self.build(**opts)
          new(values: opts)
        end

        def setup **opts, &block
          begin
            opts.each do |key, value|
              @_values[key] = opts[key.to_s.to_sym] if eligible_key?(key) || @_dynamic_keys
            end
            if block_given?
              start_setter_mode!
              instance_exec(&block)
              end_setter_mode!
            end
            self
          end
        end

        def reset
          @_values.each_key do |key|
            value = @_values[key]
            if value.is_a?(Config)
              value.reset
            else
              @_values[key] = nil
            end
          end
        end

        def dup
          copy = super
          copy_values = {}

          @_values.each do |key, value|
            copy_values[key] = case value
              when Config
                value.dup
              when Array
                value.map { |v| v.is_a?(Config) ? v.dup : (v.dup rescue v) }
              when Hash
                value.transform_values { |v| v.is_a?(Config) ? v.dup : (v.dup rescue v) }
              when Struct, OpenStruct, Set, Time
                value.dup
              else
                begin
                  value.frozen? || value.is_a?(Numeric) || value.is_a?(Symbol) ? value : value.dup
                rescue
                  value
                end
            end
          end

          copy.instance_variable_set(:@_values, copy_values)
          copy.instance_variable_set(:@_context, @_context)
          copy.instance_variable_set(:@_setter_mode, @_setter_mode)
          copy.instance_variable_set(:@_supress, @_supress)
          copy.instance_variable_set(:@_dynamic_keys, @_dynamic_keys)
          copy
        end

        def add(key, value)
          @_values[key] = value
          self
        end

        def exists?(key)
          @_values.keys.map(&:to_s).include?(key.to_s)
        end

        def to_h
          @_values.transform_values do |value|
            value.is_a?(Config) ? value.to_h : value
          end
        end

        def values
          @_values || {}
        end

        def keys
          @_values.keys
        end

        def remove_key(key)
          @_values.delete(key)
        end

        def remove_keys(*args)
          args.each{|key| remove_key(key) }
          self
        end

        def only_keys *args
          only = args.select{|arg| exists?(arg) }
          except = keys.select{|k| !only.include?(k) }
          remove_keys(*except)
          self
        end

        def eligible_key?(key)
          @_values.keys.map(&:to_s).include?(key.to_s)
        end

        def valid_key?(key)
          if INVALID_KEYS.include?(key.to_s)
            raise "Invalid key #{key}"
          end
        end

        def valid_keys?(*keys)
          keys.each{|k| valid_key?(k) }
        end

        def start_setter_mode!
          @_setter_mode = true
          values.each do |key, value|
            if value.is_a?(Config)
              value.start_setter_mode!
            end
          end
        end

        def end_setter_mode!
          @_setter_mode  = false
          values.each do |key, value|
            if value.is_a?(Config)
              value.end_setter_mode!
            end
          end
        end

        def supress!
          @supress = true
          values.each do |key, value|
            if value.is_a?(Config)
              value.supress!
            end
          end
        end

        def unsupress!
          @supress = false
          values.each do |key, value|
            if value.is_a?(Config)
              value.unsupress!
            end
          end
        end

        def dynamic_keys!
          @_dynamic_keys = true
          values.each do |key, value|
            if value.is_a?(Config)
              value.dynamic_keys!
            end
          end
        end

        def with_dynamic_keys &block
          if block_given?
            dynamic_keys!
            instance_exec(&block)
            static_keys!
          end
        end

        def static_keys!
          @_dynamic_keys = false
          values.each do |key, value|
            if value.is_a?(Config)
              value.static_keys!
            end
          end
        end

        def initialize(values: {}, &block)
          valid_keys?(*values.keys)
          @_values = values.dup
        end

        def with_context _context, &block
          original_context = @_context
          set_context(_context)
          result = yield
          set_context(original_context)
          result
        end

        def set_context(context)
          @_context = context
          values.each do |_, value|
            case value
            when Config
              value.set_context(context)
            end
          end
        end

        def evaluate_with_context(val, *args)
          if @_context
            if val.is_a?(Symbol)
              @_context.smart_send(val, args)
            elsif val.is_a?(Proc)
              @_context.instance_exec(*args, &val)
            elsif val.is_a?(UnboundMethod)
              val.bind(@_context).call(*args)
            else
              val
            end
          else
            raise "Context not set"
          end
        end

        def set(key, *args, &block)
          key = key.to_sym
          valid_key?(key)
          if eligible_key?(key) || @_dynamic_keys
            current_value = @_values[key]
            case current_value
            when Collection
              if block_given?
                current_value.start_setter_mode!
                current_value.instance_exec(*args, &block)
                current_value.end_setter_mode!
              elsif args.length > 0
                args.flatten.each { |name| current_value.public_send(name) }
              end
              @_values[key] = current_value
            when Config
              if block_given?
                current_value.start_setter_mode!
                current_value.instance_exec(*args, &block)
                current_value.end_setter_mode!
              else
                if args[0].is_a?(Config)
                  cfg = args[0].dup
                  cfg.set_context(@_context)
                  @_values[key] = cfg
                else
                  raise ArgumentError, "You must provide a block to set a Config value"
                end
              end
            else
              if block_given?
                @_values[key] = block
              else
                @_values[key] = args.first
              end
            end
          end
        end

        def set!(key, *args, &block)
          if eligible_key?(key) || @_dynamic_keys
            @_values[key.to_sym] = args.first
          end
        end

        def get(key, *args)
          current_value = @_values[key]
          if current_value.is_a?(Proc) || current_value.is_a?(Symbol) || current_value.is_a?(UnboundMethod)
            evaluate_with_context(current_value, *args)
          else
            current_value
          end
        end

        def method_missing(name, *args, &block)
          key = name.to_s.chomp("=").to_sym
          if eligible_key?(key) || @_dynamic_keys
            unless @_values.keys.map(&:to_s).include?(key.to_s)
              @_values[key.to_sym] = nil
            end
            if name.to_s.end_with?("=")
              current_value = @_values[key]
              if current_value.is_a?(Config)
                if block_given?
                  current_value.instance_exec(*args, &block)
                  raise ArgumentError, "You must provide a Config object for #{name}"
                else
                  set(key, *args)
                end
              else
                if args.length > 0 || block_given?
                  set(key, *args, &block)
                else
                  raise ArgumentError
                end
              end
            else
              if @_setter_mode
                if block_given?
                  set(key, *args, &block)
                else
                  current_value = @_values[key]
                  if current_value.is_a?(Config)
                    @_values[key]
                  else
                    set(key, *args)
                  end
                end
              else
                get(key, *args)
              end
            end
          else
            super(name, *args, &block) unless @supress
          end
        end

        def [](key)
          @_values[key.to_sym]
        end

      end
    end
  end
end
