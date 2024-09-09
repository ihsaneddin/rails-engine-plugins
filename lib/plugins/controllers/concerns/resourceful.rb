module Plugins
  module Controllers
    module Concerns
      module Resourceful

        extend ActiveSupport::Concern
        include Plugins::Controllers::Concerns::Paginated
        include Plugins::Controllers::Concerns::Responder

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

        included do

          class_attribute :resourceful_params_
          self.resourceful_params_ = {}

        end

        module ClassMethods

          def init_resourceful_params
            self.resourceful_params_[self.to_s] = {
              model_klass: nil,
              resource_identifier: nil,
              resource_finder_key: nil,
              query_scope: nil,
              query_includes: nil,
              after_fetch_resource: nil,
              resource_actions: [ :show, :new, :create, :edit, :update, :destroy ],
              resources_actions: [ :index ],
              resource_params_attributes: [],
              should_paginate: true
            }
          end

          def resourceful_params key=nil
            if self.resourceful_params_[self.to_s].blank?
              init_resourceful_params
            end
            if(key)
              return self.resourceful_params_[self.to_s][key]
            else
              return self.resourceful_params_[self.to_s]
            end
          end

          def resourceful_params_merge! opts = {}
            current_opts = resourceful_params
            current_opts = current_opts.merge!(opts)
            self.resourceful_params_[self.to_s] = current_opts
          end

          def set_resource_param key, value
            if self.resourceful_params_[self.to_s].blank?
              init_resourceful_params
            end
            self.resourceful_params_[self.to_s][key] = value
          end

          def fetch_resource_and_collection!(args = {}, &block)
            fetch_resource! args, &block
            fetch_resources! args, &block
          end

          def fetch_resource!(args = {}, &block)
            resourceful_params.merge!(args)
            yield if block_given?
            before_action :fetch_resource, only: resource_actions
          end

          def fetch_resources!(args = {}, &block)
            resourceful_params.merge!(resourceful_params)
            yield if block_given?
            before_action :fetch_resources, only: resources_actions
          end

          def attr_accessor_name
            self.to_s.demodulize.singularize.camelcase
          end

          def model_klass(klass = nil)
            if klass.nil?
              klass = self.resourceful_params[:model_klass]
              if klass.blank?
                klass= self.to_s.demodulize.singularize.camelcase
                set_resource_param :model_klass, klass
              end
              klass
            else
              set_resource_param :model_klass, klass
              klass
            end
          end

          def class_exists?(klass)
            klass = Module.const_get(klass)
            klass.is_a?(Class) && klass < ActiveRecord::Base
          rescue NameError
            false
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

          def resource_identifier(identifier = nil, &block)
            if identifier.blank? && !block_given?
              identifier = resourceful_params(:resource_identifier)
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

          def resource_actions actions = nil, &block
            if (actions.blank? && !actions.is_a?(Array)) && !block_given?
              actions = resourceful_params(:resource_actions)
              actions.respond_to?(:call) ? actions.call : actions
            else
              if block_given?
                set_resource_param(:resource_actions, block)
              else
                set_resource_param(:resource_actions, actions)
              end
            end
          end

          def append_resource_actions *_actions
            actions = resourceful_params(:resource_actions)
            actions = (actions || []) + _actions
            resource_actions actions
          end

          def resources_actions actions = nil, &block
            if (actions.blank? && !actions.is_a?(Array)) && !block_given?
              actions = resourceful_params(:resources_actions)
              actions.respond_to?(:call) ? actions.call : actions
            else
              if block_given?
                set_resource_param(:resources_actions, block)
              else
                set_resource_param(:resources_actions, actions)
              end
            end
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

          def should_paginate? pg = nil, &block
            if pg.blank? && !block_given?
              pg = resourceful_params(:should_paginate)
              pg.blank?? false : pg
            else
              if block_given?
                set_resource_param :should_paginate, block
              else
                set_resource_param :should_paginate, pg
              end
            end
          end

        end

        def records
          @_resources
        end

        def record
          @_resource
        end

        def fetch_resource
          return @_resource unless @_resource.nil?
          @_resource = _get_resource
          instance_variable_set("@#{self.class.attr_accessor_name}", @_resource)
        end

        def fetch_resources
          return @_resources unless @_resources.nil?
          @_resources = _get_resources
          instance_variable_set("@#{self.class.attr_accessor_name.pluralize}", @_resources)
        end

        def _get_resource
          got_resource = _identifier_param_present? ? _existing_resource : _new_resource
          get_value(:after_fetch_resource, got_resource) || got_resource
          got_resource
        end

        def _get_resources
          _query
        end

        def _identifier_param_present?
          identifier = _resource_identifier
          params[identifier.to_sym].present?
        end

        def _model_klass
          model_klass = get_value :model_klass
          model_klass
        end

        def model_klass_constant
          return @_model_klass if @_model_klass
          klass = _model_klass
          if self.class.class_exists?(klass)
            klass.constantize
          else
            klass.constantize
          end
        rescue
          raise { ActiveRecord::RecordNotFound }
        end

        def _resource_identifier
          identifier = get_value :resource_identifier
          if identifier.blank?
            identifier = model_klass_constant.primary_key
          end
          identifier
        end

        def _resource_finder_key
          key = get_value :resource_finder_key
          if key.blank?
            key = model_klass_constant.primary_key
          end
          key
        end

        def _query
          model = _apply_query_includes(model_klass_constant)
          query = get_value(:query_scope, model) || model.where.not(id: nil)
          if(params[:order_by])
            query = query.order params[:order_by]
          end
          query
        end

        def _apply_query_includes query
          _query_includes = get_value :query_includes
          unless _query_includes.blank?
            if _query_includes.is_a?(Array)
              query = query.includes(*_query_includes)
            else
              query = query.includes(_query_includes)
            end
          end
          query
        end

        def build_recursive_params(recursive_key:, parameters: params, permitted_attributes:)
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

        def _identifier
          id = _resource_identifier
          id = id.is_a?(String)? id.to_sym : id
          if id.is_a? Symbol
            finder_key = _resource_finder_key
            par = { "#{finder_key}": params[id] }
          elsif id.is_a? Array
            Hash[id.map { |i| [i, params[i]] }]
          else
            {}
          end
        end

        def _new_resource
          model_klass_constant.new permitted_attributes
        end

        def permitted_attributes
          _resource_params
        end

        def _resource_params
          attributes = {}
          _permitted_attributes = get_value :resource_params_attributes
          return attributes if _permitted_attributes.blank?
          if params[self.class.attr_accessor_name.to_sym].present?
            attributes = params.require(self.class.attr_accessor_name.to_sym).permit(_permitted_attributes)
          else
            attributes = params.permit(_permitted_attributes)
          end
          attributes
        end

        def _existing_resource
          resource = _query.send('find_by!', _identifier)
          resource
        end

        def resource
          instance_variable_get("@#{self.class.attr_accessor_name}")
        end

        def with_resource &block
          fetch_resource if resource.nil?
          yield if resource.present?
        end

        def pagination_info
          hash = {}
          if headers
            config = Plugins.config.api.pagination.config
            hash[config.per_page] = headers[config.per_page].to_i
            hash[config.page] = headers[config.page].to_i if config.page
            if config.include_total
              hash[config.total] = headers[config.total].to_i
              if hash[config.per_page].to_i > 0
                hash[config.total_page] = (hash[config.total].to_f / hash[config.per_page]).ceil
                if hash[config.page]
                  hash[config.last_page] = hash[config.page] >= hash["Total-Pages"]
                end
              end
            end
            hash
          end
        end

        def get_value key, arg = nil
          value = self.class.resourceful_params key.to_sym
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

        def present data, *args
          meta = {}
          if data.is_a?(ActiveRecord::Relation)
            should_paginate = get_value :should_paginate
            if should_paginate
              data = paginate(data)
              pagination = pagination_info
              args << {pagination: pagination}
            end
          end
          super(data, *args)
        end

        # def present data, *args
        #   if data.is_a?(ActiveRecord::Relation)
        #     should_paginate = get_value :should_paginate
        #     if should_paginate
        #       pagy, data = pagy(data)
        #       pagination = {
        #         current_page: pagy.page,
        #         total_pages: pagy.pages,
        #         per_page: pagy.items,
        #         total_count: pagy.count
        #       }
        #       args << {pagination: pagination}
        #     end
        #   end
        #   super(data, *args)
        # end



      end
    end
  end
end