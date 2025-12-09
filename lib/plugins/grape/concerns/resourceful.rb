module Plugins
  module Grape
    module Concerns
      module Resourceful

        def self.included base
          base.class_eval do
            class_attribute :resourceful_params_
            self.resourceful_params_ = {}
          end
          base.extend ClassMethods
          ::Grape::Endpoint.include HelperMethods if defined? ::Grape::Endpoint
        end

        class Blocks

          attr_accessor :blocks

          def initialize blocks = []
            self.blocks  = blocks || []
          end

          def call context, *args
            ret = nil
            blocks.each do |block|
              if args.blank?
                ret = context.instance_exec(&block)
              else
                ret = args
                ret = context.instance_exec(*ret, &block)
              end
            end
            ret
          end

        end

        module ClassMethods

          def resourceful_params key=nil
            if self.resourceful_params_[self.to_s].blank?
              self.resourceful_params_[self.to_s] = {
                resource_context: nil,
                executed: [],
                model_klass: nil,
                resource_identifier: nil,
                resource_finder_key: nil,
                resource_params_attributes: [],
                resource_friendly: false,
                resource_finder: nil,
                resource_var_name: nil,
                query_includes: nil,
                query_scope: nil,
                resource_actions: [ :show, :new, :create, :edit, :update, :destroy ],
                resources_actions: [ :index ],
                after_fetch_resource: nil,
                should_paginate: true,
              }
            end
            if(key)
              return self.resourceful_params_[self.to_s][key]
            else
              return self.resourceful_params_[self.to_s]
            end
          end

          def is_executed? name
            return false
            #self.resourceful_params(:executed).include?(name)
          end

          def resourceful_params_merge! opts = {}
            current_opts = resourceful_params
            current_opts = current_opts.merge!(opts)
            self.resourceful_params_[self.to_s] = current_opts
          end

          def set_resource_param key, value
            self.resourceful_params if self.resourceful_params_[self.to_s].blank?
            self.resourceful_params_[self.to_s][key] = value
          end

          def add_resource_actions *actions
           set_resource_param(:resource_actions, self.resourceful_params[:resource_actions] + actions)
          end

          def add_resources_actions *actions
            set_resource_param(:resources_actions, self.resourceful_params[:resources_actions] + actions)
          end

          def fetch_resource_and_collection! args= {}, &block
            only = args.delete :only
            except = args.delete :except
            yield if block_given?
            fetch_resources!(({only: only, except: except}))
            fetch_resource!({only: only, except: except})
          end

          def fetch_resource!(args = {}, &block)
            only = args.delete(:only) || resource_actions
            except = args.delete(:except)
            prc = block
            self.resourceful_params_merge!(args)
            self.instance_exec(&prc) if block_given?
            after_validation do
              unless route.settings[:skip_resource]
                if actions_resolve(only, except)
                  _set_resource()
                end
              end
            end
          end

          def fetch_resources!(args= {}, &block)
            only = args.delete(:only) || resources_actions
            except = args.delete(:except)
            prc = block
            self.resourceful_params_merge!(args)
            self.instance_exec(&prc) if block_given?
            after_validation do
              unless route.settings[:skip_resources]
                if actions_resolve(only, except)
                  _set_resources()
                end
              end
            end
          end

          def resource_actions
            self.resourceful_params[:resource_actions]
          end

          def resources_actions
            self.resourceful_params[:resources_actions]
          end

          def model_klass(klass = nil, &block)
            if klass.nil? & !block_given?
              klass = self.resourceful_params[:model_klass]
              if klass.blank?
                klass= self.to_s.demodulize.singularize.camelcase
                set_resource_param :model_klass, klass
              end
              klass
            else
              if block_given?
                set_resource_param(:model_klass, block)
              else
                set_resource_param :model_klass, klass
              end
              klass
            end
          end

          def attributes &block
            params &block
          end

          def class_exists?(klass)
            klass = Module.const_get(klass)
            klass.is_a?(Class) && klass < ActiveRecord::Base
          rescue NameError
            false
          end

          def query_includes(includes = nil, &block)
            if includes.nil? && !block_given?
              resourceful_params(:includes)
            else
              if block_given?
                set_resource_param(:query_includes, block)
              else
                set_resource_param(:query_includes, includes)
              end
            end
          end

          def query_scope(query = nil, &block)
            if query.blank? && !block_given?
              resourceful_params(:query_scope)
            else
              if block_given?
                set_resource_param :query_scope, block
              else
                set_resource_param :query_scope, query
              end
            end
          end

          def resource_identifier(identifier = nil, &block)
            if identifier.blank? && !block_given?
              identifier = resourceful_params(:resource_identifier)
              if identifier.blank?
                identifier = "id"
                set_resource_param :resource_identifier, identifier
              end
              identifier
            else
              if block_given?
                set_resource_param(:resource_identifier, block)
              else
                set_resource_param(:resource_identifier, identifier)
              end
            end
          end

          def resource_finder_key(key = nil, &block)
            if key.blank? && !block_given?
              key = resourceful_params(:resource_finder_key)
              if key.nil?
                key = "id"
                set_resource_param :resource_finder_key, key
              end
              key
            else
              if block_given?
                set_resource_param(:resource_finder_key, block)
              else
                set_resource_param(:resource_finder_key, key)
              end
            end
          end

          def resource_identifier_and_finder_key identifier
            resource_identifier identifier
            resource_finder_key identifier
          end

          def resource_params_attributes(*attributes, &block)
            if attributes.blank? && !block_given?
              resourceful_params(:resource_params_attributes)
            else
              if block_given?
                set_resource_param(:resource_params_attributes, block)
              else
                set_resource_param(:resource_params_attributes, attributes)
              end
            end
          end

          def resource_friendly?(friendly = nil, &block)
            return
          end

          def resource_finder(finder = nil, &block)
            if finder.blank? && !block_given?
              finder = resourceful_params(:resource_finder)
              if finder.nil?
                finder = proc { |query, identifier|
                  query.send('find_by!', identifier)
                }
                set_resource_param :resource_finder, finder
              end
              finder
            else
              if block_given?
                set_resource_param(:resource_finder, block)
              else
                raise ArgumentError, "Block is required!"
              end
            end
          end

          def after_fetch_resource proc = nil, &block
            if proc.blank? && !block_given?
              self.resourceful_params[:after_fetch_resource]
            else
              if block_given?
                set_resource_param :after_fetch_resource, block
              else
                set_resource_param :after_fetch_resource, proc
              end
            end
          end

          def should_paginate? pg = nil, &block
            if pg.blank? && !block_given?
              pg = self.resourceful_params[:should_paginate]
              if pg.blank?
                pg = false
                set_resource_param :should_paginate, pg
              end
              pg
            else
              if block_given?
                set_resource_param :should_paginate, block
              else
                set_resource_param :should_paginate, pg
              end
            end
          end

          def resource_context ctx = nil, &block
            if ctx.blank? && !block_given?
              ctx = self.resourceful_params[:resource_context]
              if ctx.blank?
                set_resource_param :resource_context, ctx
              end
              ctx
            else
              if block_given?
                set_resource_param :resource_context, block
              else
                set_resource_param :resource_context, ctx
              end
            end
          end

          def resource_var_name var_name= nil, &block
             if var_name.blank? && !block_given?
              resourceful_params(:resource_var_name)
            else
              if block_given?
                set_resource_param(:resource_var_name, block)
              else
                set_resource_param(:resource_var_name, var_name)
              end
            end
          end

        end

        module HelperMethods

          def resource_context
            get_value(:resource_context)
          end

          def actions_resolve(only=nil, except=nil)
            action_name = route.options[:action]
            return true unless action_name
            return true if only.nil? && except.nil?
            if only.present?
              only = [only].flatten
              only.any?{|o| o.to_s == action_name.to_s }
            else
              if except.present?
                except = [except].flatten
                except.any?{|e| e.to_s != action_name.to_s }
              end
            end
          end

          def get_value key, *args
            value = class_context do |context|
              context.resourceful_params key.to_sym
            end

            if value.nil? && ![:model_klass, :resource_context].include?(key)
              mod = model_class_constant
              if mod.include?(::Plugins::Models::Concerns::ApiResource)
                if cfg = mod.grape_api_resource_of(value)
                  args << self
                  value = cfg.get(key, *args) if cfg.exists?(key)
                end
              end
            end

            if value.is_a?(Blocks)
              if args.length > 0
                value = value.call(self, *args)
              else
                value = value.call(self)
              end
            end
            if value.is_a?(Proc)
              if args
                value = instance_exec(*args, &value)
              else
                value = instance_exec(&value)
              end
            end
            value
          end

          def declared_permitted_params
            @declared_permitted_params ||= declared(params, include_missing: false, include_parent_namespaces: false)
          end

          def _set_resource(context=nil)
            return unless @_resource.nil?
            var_name = resource_var_name
            @_resource = _get_resource
            instance_variable_set("@#{var_name}", @_resource)
          end

          def _get_resource
            got_resource = _identifier_param_present? ? _existing_resource : _new_resource
            get_value(:after_fetch_resource, got_resource) || got_resource
            got_resource
          end

          def resource_var_name
            get_value(:resource_var_name) || _model_klass.demodulize.underscore.downcase
          end

          def _identifier_param_present?
            params[_resource_identifier.to_sym].present?
          end

          def _resource_identifier
            identifier = get_value :resource_identifier
            if identifier.blank?
              identifier = model_class_constant.primary_key
            end
            identifier
          end

          def _resource_finder_key
            identifier = get_value :resource_finder_key
            if identifier.blank?
              identifier = model_class_constant.primary_key
            end
            identifier
          end

          def _new_resource
            if(class_context)
              model_class_constant.new _resource_params
            end
          end

          def model_class_constant
            klass = _model_klass
            if klass.is_a?(String) && class_context.class_exists?(klass)
              @_model_klass = klass.constantize
            else
              @_model_klass = klass
            end
          rescue
            raise { ActiveRecord::RecordNotFound }
          end

          def _model_klass
            model_klass = get_value :model_klass
            model_klass
          end

          def posts
            @strong_parameter_object ||= ActionController::Parameters.new(params)
          end

          def permitted_attributes
            _resource_params
          end

          def permitted_params
            _resource_params
          end

          def _resource_params
            attributes = {}
            if(class_context)
              attributes  = declared_permitted_params
              if attributes.empty?
                if posts.present?
                  _resource_params_attributes_ = get_value :resource_params_attributes
                  if _resource_params_attributes_.blank?
                    attributes = {}
                  else
                    attributes = posts.permit(_resource_params_attributes_)
                  end
                end
              end
            end
            if route.settings[:upload_attributes]
              attributes = normalize_file_params!(attributes)
            end
            attributes
          end

          def _apply_query_includes query
            query_includes = get_value :query_includes
            unless query_includes.blank?
              if query_includes.is_a?(Array)
                query = query.includes(*query_includes)
              else
                query = query.includes(query_includes)
              end
            end
            query
          end

          def build_recursive_params(recursive_key:, parameters: posts, permitted_attributes:)
            template = { recursive_key => permitted_attributes }

            nested_permit_list = template.deep_dup
            current_node = nested_permit_list[recursive_key]

            nested_count = parameters.to_s.scan(/#{recursive_key}/).count
            (1..nested_count).each do |i|
              new_element = template.deep_dup
              current_node << new_element
              current_node = new_element[recursive_key]
            end
            nested_permit_list
          end

          def _query
            if(class_context)
              model = _apply_query_includes(model_class_constant)
              query = get_value(:query_scope, model.where.not(id: nil)) || model.where.not(id: nil)
              if(params[:order_by])
                query = query.order params[:order_by]
              end
              query
            end
          end

          def model_class
            model_class_constant
          end

          def _identifier
            if class_context
              id = _resource_identifier
              id = id.is_a?(String)? id.to_sym : id
              if id.is_a? Symbol
                finder_key = _resource_finder_key
                par = { "#{finder_key}": params[id] }
                par
              elsif id.is_a? Array
                Hash[id.map { |i| [i, params[i]] }]
              else
                {}
              end
            end
          end

          def _existing_resource
            if class_context
              _resource_ = get_value(:resource_finder, _query, _identifier) || _query.send('find_by!', _identifier)
              if _resource_.nil?
                raise ActiveRecord::RecordNotFound
              end
              _resource_
            end
          end

          def _set_resources()
            return unless @_resources.nil?
            var_name = resource_var_name.pluralize
            should_paginate = get_value(:should_paginate)
            @_resources = should_paginate ? paginate(_get_resources) : _get_resources
            instance_variable_set("@#{var_name}", @_resources)
          end

          def _get_resources
            _query
          end
          def records
            _resources
          end

          def _resources
            return instance_variable_get("@#{resource_var_name.pluralize}")
          end

          def record
            _resource
          end

          def _resource
            return instance_variable_get("@#{resource_var_name}")
          end

          def normalize_file_params!(hash)
            return hash unless hash.is_a?(Hash)

            hash.each do |key, value|
              if file_param?(value)
                hash[key] = to_uploaded_file(value)
              elsif value.is_a?(Hash)
                normalize_file_params!(value)
              elsif value.is_a?(Array)
                hash[key] = value.map do |item|
                  file_param?(item) ? to_uploaded_file(item) : item
                end
              end
            end

            hash
          end

          def file_param?(value)
            value.is_a?(Hash) &&
              value.key?(:tempfile) &&
              value[:tempfile].is_a?(Tempfile) &&
              value.key?(:filename)
          end

          def to_uploaded_file(value)
            ActionDispatch::Http::UploadedFile.new(
              filename: value[:filename],
              type:     value[:type],
              tempfile: value[:tempfile],
              head:     value[:head]
            )
          end

        end

      end
    end
  end
end