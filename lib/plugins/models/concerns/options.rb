module Plugins
  module Models
    module Concerns
      module Options

        module ClassMethods

          def build_options base, key, *opts
            with_defaults = opts.extract_options!

            opts = opts.reduce({}){|_opts, k|
              _opts[k.to_sym]= nil
              _opts
            }

            singular_key = "#{key}_opt"
            plural_key = "#{key}_opts"
            class_attribute_key = "_#{key}_opts"
            config_class_key = "#{key}_config_class"

            base.class_attribute class_attribute_key.to_sym
            base.send("#{class_attribute_key}=", opts.merge(with_defaults))

            base.class_eval <<-CODE, __FILE__, __LINE__ + 1
              class Config#{key.classify}
                attr_accessor '#{key}'.to_sym

                def initialize base
                  self.#{key} = base
                end

              end

              class_attribute '#{config_class_key}'.to_sym
              self.#{config_class_key} = Config#{key.classify}

              def self.#{plural_key} key= nil
                if(key)
                  return self.#{class_attribute_key}[key]
                else
                  return self.#{class_attribute_key}
                end
              end

              def self.get_#{singular_key} key, arg = nil
                value = #{plural_key} key.to_s.to_sym
                if value.is_a?(Proc)
                  if arg
                    value = instance_exec(arg, &value)
                  else
                    value = instance_exec(&value)
                  end
                elsif value.is_a?(Symbol)
                  value = send(value)
                end
                value
              end

              def self.set_#{singular_key} key, value
                self.#{class_attribute_key}[key] = value
              end

              def get_#{singular_key} key, *args
                value = self.class.#{plural_key} key.to_s.to_sym
                if value.is_a?(Proc)
                  if args.present?
                    value = instance_exec(*args, &value)
                  else
                    value = instance_exec(&value)
                  end
                elsif value.is_a?(Symbol)
                  if args.present?
                    value = send(value, *args)
                  else
                    value = send(value)
                  end
                end
                value
              end
            CODE

            accept_config_block(base, class_attribute_key, config_class_key, key, plural_key, singular_key)

          end

          def accept_config_block base, class_attribute_key, config_class_key, key, plural_key, singular_key
            base.send(class_attribute_key).each do |k,v|
              base.send(config_class_key).class_eval <<-CODE, __FILE__, __LINE__ + 1
                def #{k}(opt= nil, &block)
                  if opt.blank? && !block_given?
                    opt = self.#{key}.send('#{plural_key}', '#{k}'.to_sym)
                    opt
                  else
                    if block_given?
                      self.#{key}.send('set_#{singular_key}', '#{k}'.to_sym, block)
                    else
                      self.#{key}.send('set_#{singular_key}', '#{k}'.to_sym, opt)
                    end
                  end
                end
              CODE
            end
          end

        end

        extend ClassMethods


      end
    end
  end
end