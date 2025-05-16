module Plugins
  module Models
    module Concerns
      class Config

        attr_reader :values, :context, :setter_mode

        def self.setup(base, config_name, *keys)

          base.include ::Plugins::Models::Concerns::Options::InheritableClassAttribute
          base.inheritable_class_attribute config_name.to_sym

          opts = keys.extract_options!

          opts = opts.merge(keys.reduce({}){|_opts, k|
            _opts[k.to_sym]= nil
            _opts
          })

          config = new
          config.instance_variable_set(:@values, opts)
          config.set_context(base)

          base.define_singleton_method(config_name) { config }
          base.define_method(config_name) { config }

          base.singleton_class.define_method(:inherited) do |subclass|
            super(subclass)
            subclass_config = config.dup
            subclass_config.set_context(subclass)
            subclass.send("#{config_name}=", subclass_config)
            subclass.define_singleton_method(config_name) { subclass_config }
            subclass.define_method(config_name) { subclass_config }
          end

        end

        def setup **opts, &block
          @values = @values.merge(opts)
          if block_given?
            start_setter_mode!
            instance_exec(&block)
            end_setter_mode!
          end
        end

        def reset
          @values.each_key do |key|
            value = @values[key]
            if value.is_a?(Config)
              value.reset
            else
              @values[key] = nil
            end
          end
        end

        def to_h
          @values.transform_values do |value|
            value.is_a?(Config) ? value.to_h : value
          end
        end

        def eligible_key?(key)
          @values.keys.map(&:to_s).include?(key.to_s)
        end

        def start_setter_mode!
          @setter_mode = true
        end

        def end_setter_mode!
          @setter_mode  = false
        end

        def initialize
          @values = {}
        end

        def set_context(context)
          @context = context
          values.each do |key, value|
            if value.is_a?(Config)
              value.set_context(context)
            end
          end
        end

        def evaluate_with_context(val, *args)
          if @context
            if val.is_a?(Symbol)
              @context.send(val, *args)
            elsif val.is_a?(Proc)
              @context.instance_exec(*args, &val)
            else
              val
            end
          else
            raise "Context not set"
          end
        end

        def set(key, *args, &block)
          key = key.to_sym
          if eligible_key?(key)
            current_value = @values[key]
            if current_value.is_a?(Config)
              if block_given?
                @values[key] = current_value.instance_exec(*args, &block)
              else
                raise ArgumentError, "You must provide a block to set a Config value"
              end
            else
              @values[key] = args.first
            end
          end
        end

        def set!(key, *args, &block)
          if eligible_key?(key)
            @values[key.to_sym] = args.first
          end
        end

        def get(key, *args)
          current_value = @values[key]
          if current_value.is_a?(Proc)
            evaluate_with_context(*args, current_value)
          else
            current_value
          end
        end

        def method_missing(name, *args, &block)
          key = name.to_s.chomp("=").to_sym
          if eligible_key?(key)
            current_value = @values[key]
            if name.to_s.end_with?("=")
              if current_value.is_a?(Config)
                if block_given?
                  current_value.instance_exec(*args, &block)
                else
                  raise ArgumentError, "You must provide a block to set a Config value"
                end
              else
                if args.any?
                  values[key] = args
                else
                  raise ArgumentError
                end
              end
            else
              if @setter_mode
                set(key, *args, &block)
              else
                get(key, *args)
              end
            end
          else
            super method, *args, &block
          end
        end

        def [](key)
          @values[key.to_sym]
        end

      end
    end
  end
end