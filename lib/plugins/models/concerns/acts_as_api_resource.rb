module Plugins
  module Models
    module Concerns
      module ActsAsApiResource

        module Options
          extend Plugins::Models::Concerns::Options::ClassMethods

          class Event

            attr_accessor :name, :block

            def initialize name, block
              self.name = name
              self.block = block
            end

            @@named = []

            def self.name name, &block
              @@named << self.new(name, block)
            end

            def self.define &block
              instance_exec(&block)
            end

            def self.get_named
              @@named.dup
            end

            def self.clear_named
              @@named = []
            end

            def to_s
              self.name.to_s
            end

          end

          class ResourceEvent < Event; end
          class ResourcesEvent < Event; end

          def self.accept_config_block base, class_attribute_key, config_class_key, key, plural_key, singular_key
            base.send(class_attribute_key).each do |k,v|
              if k.to_sym == :resource_events
                base.send(config_class_key).class_eval <<-CODE, __FILE__, __LINE__ + 1
                  def #{k}(opt= nil, &block)
                    if opt.blank? && !block_given?
                      opt = self.#{key}.send('#{plural_key}', '#{k}'.to_sym)
                      opt
                    else
                      if block_given?
                        Plugins::Models::Concerns::ActsAsApiResource::Options::ResourceEvent.define &block
                        evs = Plugins::Models::Concerns::ActsAsApiResource::Options::ResourceEvent.get_named
                        self.#{key}.send('set_#{singular_key}', '#{k}'.to_sym, evs)
                        Plugins::Models::Concerns::ActsAsApiResource::Options::ResourceEvent.clear_named
                      else
                        self.#{key}.send('set_#{singular_key}', '#{k}'.to_sym, opt)
                      end
                    end
                  end
                CODE
              elsif k.to_sym == :resources_events
                base.send(config_class_key).class_eval <<-CODE, __FILE__, __LINE__ + 1
                  def #{k}(opt= nil, &block)
                    if opt.blank? && !block_given?
                      opt = self.#{key}.send('#{plural_key}', '#{k}'.to_sym)
                      opt
                    else
                      if block_given?
                        Plugins::Models::Concerns::ActsAsApiResource::Options::ResourcesEvent.define &block
                        evs = Plugins::Models::Concerns::ActsAsApiResource::Options::ResourcesEvent.get_named
                        self.#{key}.send('set_#{singular_key}', '#{k}'.to_sym, evs)
                        Plugins::Models::Concerns::ActsAsApiResource::Options::ResourcesEvent.clear_named
                      else
                        self.#{key}.send('set_#{singular_key}', '#{k}'.to_sym, opt)
                      end
                    end
                  end
                CODE
              else
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

        end

        def self.included base
          extend ClassMethods
        end

        module ClassMethods

          def acts_as_api_resource *opts, &block
            default = {
              model_klass: proc { self.name },
              resources_path: proc { self.name.demodulize.underscore.pluralize },
              resource_path: proc { self.name.demodulize.underscore.singularize },
              resource_identifier: proc { self.primary_key },
              resource_finder_key: proc { self.primary_key },
              resource_params_attributes: [],
              resource_friendly: false,
              query_includes: nil,
              query_scope: nil,
              resource_actions: [ :show, :new, :create, :edit, :update, :destroy ],
              resources_actions: [ :index ],
              after_fetch_resource: nil,
              should_paginate: true,
              presenter_class: nil,
              grape_presenter_class: nil,
              resource_events: [],
              resources_events: [],
            }
            Plugins::Models::Concerns::ActsAsApiResource::Options.build_options(self, "acts_as_api_resource", default.merge(opts))
            config = self.acts_as_api_resource_config_class.new(self)
            if block_given?
              config.instance_exec(&block)
            end
            extend Core
          end

        end

        module Core

        end

      end
    end
  end
end