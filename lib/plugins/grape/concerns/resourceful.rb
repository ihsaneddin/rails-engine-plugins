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

          def call context, arg = nil
            ret = nil
            blocks.each do |block|
              if arg.nil?
                ret = context.instance_exec &block
              else
                ret = arg
                ret = context.instance_exec ret, &block
              end
            end
            ret
          end

        end

        module ClassMethods

          def resourceful_params key=nil
            if self.resourceful_params_[self.to_s].blank?
              self.resourceful_params_[self.to_s] = {
                executed: [],
                model_klass: nil,
                resource_identifier: nil,
                resource_finder_key: nil,
                #resource_params_key: nil,
                resource_params_attributes: [],
                resource_friendly: false,
                query_includes: nil,
                query_scope: nil,
                resource_actions: [ :show, :new, :create, :edit, :update, :destroy ],
                collection_actions: [ :index ],
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
            self.resourceful_params(:executed).include?(name)
          end

          def resourceful_params_merge! opts = {}
            current_opts = resourceful_params
            current_opts = current_opts.merge!(opts)
            self.resourceful_params_[self.to_s] = current_opts
          end

          def set_resource_param key, value
            self.resourceful_params_[self.to_s][key] = value
          end

          def fetch_resource_and_collection! args= {}, &block
            fetch_resource! args, &block
            fetch_resources! args, &block
          end

          def actions_resolve(only=nil, except=nil)
            action_name = route.options(:action)
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

          def fetch_resource!(args = {}, &block)
            only = args.delete(:only) || resource_actions
            except = args.delete(:except)
            context = self
            prc = block
            after_validation do
              unless route.settings[:skip_resource]
                if actions_resolve(only, except)
                  context.resourceful_params_merge!(args)
                  context.instance_exec(&prc) if prc
                  _set_resource(context)
                end
              end
            end
          end

          def fetch_resources!(args= {}, &block)
            only = args.delete(:only) || collection_actions
            except = args.delete(:except)
            context = self
            prc = block
            after_validation do
              unless route.settings[:skip_resources]
                if actions_resolve(only, except)
                  context.resourceful_params_merge!(resourceful_params)
                  context.instance_exec(&prc) if prc
                  _set_collection(context)
                end
              end
            end
          end

          # def fetch_resource_and_collection!(resourceful_params = {}, &block)
          #   fetch_resource! resourceful_params
          #   fetch_collection! resourceful_params
          #   unless is_executed? :fetch_resource_and_collection!
          #     yield if block_given?
          #     set_resource_param :executed, resourceful_params(:executed).append(:fetch_resource_and_collection!).uniq
          #   end
          # end


          # def fetch_resource!(args = {}, &block)
          #   resourceful_params_merge!(args)
          #   unless is_executed? :fetch_resource!
          #     yield if block_given?
          #     set_resource_param :executed, resourceful_params(:executed).append(:fetch_resource!).uniq
          #   end
          #   context = self
          #   after_validation do
          #     unless route.settings[:skip_resource]
          #       _set_resource(context)
          #     end
          #   end
          # end

          # def fetch_collection!(resourceful_params = {}, &block)
          #   resourceful_params_merge!(resourceful_params)
          #   unless is_executed? :fetch_collection!
          #     yield if block_given?
          #     set_resource_param :executed, resourceful_params(:executed).append(:fetch_collection!).uniq
          #   end
          #   context = self
          #   after_validation do
          #     unless route.settings[:skip_collection]
          #       _set_collection(context)
          #     end
          #   end
          # end


          # def actions(kind: :resource, only: [], except: [], also: [])
          #   kind = (kind.to_s + '_actions').to_sym
          #   current_params = resourceful_params
          #   current_params[kind] = current_params[kind].filter{ |action| only.is_a?(Array) ? only.include?(action) : only.to_s.eql?(action.to_s) } unless only.empty?
          #   current_params[kind] = current_params[kind].filter{ |action| except.is_a?(Array) ? !except.include?(action) : !except.to_s.eql?(action.to_s) } unless except.empty?
          #   current_params[kind] = (current_params[kind] + also).flatten.uniq unless also.empty?
          #   resourceful_params_merge!(current_params)
          #   current_params[kind]
          # end

          def resource_actions
            self.resourceful_params[:resource_actions]
          end

          def collection_actions
            self.resourceful_params[:collection_actions]
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
                set_resource_param(:resource_finder_key, identifier)
              end
            end
          end

          def resource_identifier_and_finder_key identifier
            resource_identifier identifier
            resource_finder_key identifier
          end

          # def resource_params_key(key = nil)
          #   if key.nil?
          #     key = resourceful_params(:resource_params_key)
          #     if(key.nil?)
          #       key = model_klass.underscore.downcase.to_sym
          #       set_resource_param(:resource_params_key, key)
          #     end
          #   else
          #     set_resource_param(:resource_params_key, key)
          #   end
          #   key
          # end

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
            if friendly.blank? && !block_given?
              friendly = self.resourceful_params[:resource_friendly]
              if friendly.blank?
                friendly = false
                set_resource_param :resource_friendly, friendly
              end
              friendly
            else
              if block_given?
                set_resource_param :resource_friendly, block
              else
                set_resource_param :resource_friendly, friendly
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

        end

        module HelperMethods

          def get_value key, arg = nil
            value = class_context do |context|
              context.resourceful_params key.to_sym
            end
            if value.is_a?(Blocks)
              if arg
                value = value.call(self, arg)
              else
                value = value.call(self)
              end
            end
            if value.is_a?(Proc)
              if arg
                value = instance_exec(arg, &value)
              else
                value = instance_exec(&value)
              end
            end
            value
          end

          def declared_permitted_params
            @declared_permitted_params ||= declared(params, include_missing: false, include_parent_namespaces: false)
          end

          def _set_resource(context)
            return unless @_resource.nil?
            _define_context(context)
            var_name = _model_klass.demodulize.underscore.downcase
            # var_name = class_context do |context|
            #   context.model_klass.demodulize.underscore.downcase
            # end
            @_resource = _get_resource
            instance_variable_set("@#{var_name}", @_resource)
          end

          def _get_resource
            got_resource = _identifier_param_present? ? _existing_resource : _new_resource
            # if (class_context do |context|
            #       context.after_fetch_resource.respond_to?(:call)
            #     end)
            #   after_fetch_resource = class_context do |context| context.after_fetch_resource end
            #   instance_exec(got_resource, &after_fetch_resource)
            # end
            get_value(:after_fetch_resource, got_resource) || got_resource
            got_resource
          end

          def _identifier_param_present?
            params[_resource_identifier.to_sym].present?
            # if context= class_context
            #   identifier = context.resource_identifier
            #   if identifier.respond_to?(:call)
            #     identifier = instance_exec(&identifier)
            #   end
            #   params[identifier.to_sym].present?
            # end
          end

          def _resource_identifier
            identifier = get_value :resource_identifier
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
            if class_context.class_exists?(klass)
              @_model_klass = klass.constantize
            else
              @_model_klass = klass.constantize
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
              # if params[class_context.resource_params_key].present?
              attributes  = declared_permitted_params
              if attributes.empty?
                if posts.present?
                  # attributes = params.require(class_context.resource_params_key)
                  #if class_context.resource_params_attributes.blank?
                  _resource_params_attributes_ = get_value :resource_params_attributes
                  if _resource_params_attributes_.blank?
                    attributes = {}
                  else
                    #_resource_params_attributes_ = class_context.resource_params_attributes
                    # if _resource_params_attributes_.is_a?(Proc)
                    #   _resource_params_attributes_ = instance_exec(&_resource_params_attributes_)
                    # end
                    attributes = posts.permit(_resource_params_attributes_)
                  end
                end
              end
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
            # unless class_context.query_includes.blank?
            #   includes = class_context.query_includes
            #   if includes.is_a?(Array)
            #     query = query.includes(*class_context.query_includes)
            #   else
            #     query = query.includes(class_context.query_includes)
            #   end
            # end
            # query
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
              # query = get_value(:query_scope) ||
              # #query = class_context.query_scope
              # if query.respond_to?(:call)
              #   model = _apply_query_includes(model_class)
              #   query = instance_exec(model, &query)
              # else
              #   query = _apply_query_includes(query)
              #   query = query.where.not id: nil
              # end
              # if(params[:order_by])
              #   query = query.order params[:order_by]
              # end
              # if(params[:distinct])
              #   query = query.group(params[:distinct])
              # end
              query
            end
          end

          def model_class
            model_class_constant
          end

          def _identifier
            if class_context
              id = get_value :resource_identifier
              #id = class_context.resource_identifier
              # if(id.respond_to?(:call))
              #   id = instance_exec &id
              # end
              id = id.is_a?(String)? id.to_sym : id
              if id.is_a? Symbol
                finder_key = get_value :resource_finder_key
                # finder_key = class_context.resource_finder_key
                # if finder_key.respond_to? :call
                #   finder_key = instance_exec(&finder_key)
                # end
                par = { "#{finder_key}": params[id] }
                resource_friendly= get_value(:resource_friendly)
                if resource_friendly && model_class_constant.included_modules.include?("FriendlyId::Slugged")
                #if class_context.resource_friendly? && model_class_constant.included_modules.include?("FriendlyId::Slugged")
                  par[id]
                else
                  par
                end
              elsif id.is_a? Array
                Hash[id.map { |i| [i, params[i]] }]
              else
                {}
              end
            end
          end

          def _existing_resource
            if class_context
              resource_friendly = get_value :resource_friendly
              if resource_friendly && model_class_constant.included_modules.include?("FriendlyId::Slugged")
              #if class_context.resource_friendly? && class_context.model_class_constant.included_modules.include?("FriendlyId::Slugged")
                resource = _query.friendly.find(_identifier)
              else
                resource = _query.send('find_by!', _identifier)
              end
              if resource.nil?
                raise ActiveRecord::RecordNotFound
              end
              resource
            end
          end

          def _set_collection(context)
            return unless @_resources.nil?
            _define_context(context)
            var_name = get_value(:model_klass).demodulize.underscore.downcase.pluralize
            # var_name = class_context do |context|
            #   context.model_klass.demodulize.underscore.downcase.pluralize
            # end
            should_paginate = get_value(:should_paginate)
            #should_paginate = class_context.should_paginate?
            # if should_paginate.is_a?(Proc)
            #   should_paginate = instance_exec(&should_paginate)
            # end
            @_resources = should_paginate ? paginate(_get_resources) : _get_resources
            instance_variable_set("@#{var_name}", @_resources)
          end

          def _get_resources
            _query
          end

          def class_context &block
            if self.class.respond_to?(:context) && self.class.context
              block_given?? yield(self.class.context) : self.class.context
            end
          end

          def _define_context(context = null)
            if(context)
              unless self.class.respond_to?(:context)
                self.class.class_eval do
                  class_attribute :context
                  self.context = context
                end
              end
            end
            self.class.context
          end

          def records
            resources
          end

          def resources
            var_name = _model_klass.demodulize.underscore.pluralize
            return instance_variable_get("@#{var_name}")
          end

          def record
            resource
          end

          def resource
            var_name = _model_klass.demodulize.underscore.downcase
            return instance_variable_get("@#{var_name}")
          end

        end

      end
    end
  end
end