module Plugins
  module Grape
    module Concerns
      module Responder

        def self.included base
          base.class_eval do
            class_attribute :presenter_name
          end
          base.extend ClassMethods
          ::Grape::Endpoint.include HelperMethods if defined? ::Grape::Endpoint
        end

        module HelperMethods

          def get_context_presenter_name
            # if self.try(:class_context)
            #   class_context do |context|
            #     presenter_name = context.presenter_name
            #     case presenter_name
            #     when Proc
            #       instance_exec(&presenter_name)
            #     else
            #       presenter_name
            #     end
            #   end
            # end
              class_context do |context|
                presenter_name = context.presenter_name
                case presenter_name
                when Proc
                  instance_exec(&presenter_name)
                else
                  presenter_name
                end
              end
          end

          def get_context_engine_namespace
            if self.try(:class_context)
              class_context do |context|
                context.name.split("::")[0]
              end
            end
          end

          def default_presenter_class model
            default = [model.name.demodulize.classify]
            default.unshift(get_context_engine_namespace, "Grape", "Presenters")
            default.join("::")
          end

          #
          # return message
          #
          def message options={ status: "ok"}
            status options[:status].to_sym || 201
            message||= options.delete(:message)
            {
              message: message
            }
          end

          #
          # return standard validation error from object
          #
          def standard_validation_object_error object = nil, options = { message: "Unprocessable entity" }
            if object.kind_of?(ActiveRecord::Base) || options[:details].is_a?(Hash)
              options[:details] = object.errors unless options[:details].is_a?(Hash)
              error!(options, 422)
            end
          end

          #
          # return standard validation error from hash
          #
          def standard_validation_error options= {defails: {}}
            options[:error]||= "Unprocessable entity"
            if options[:message].nil?
              if options[:details].instance_of? ActiveModel::Errors
                options[:message] = options[:details].full_messages.to_sentence
              end
            end
            if options[:details].instance_of? ActiveModel::Errors
              options[:details] = options[:details].messages
            end
            status = options.delete(:status)
            error!(options, status || 422)
          end

          def standar_success_message options = {}

          end

          def standard_not_found_error options= { message: {} }
            options[:error]||= "Not Found"
            status = options.delete(:status)
            error!(options, status || options[:message].parameterize.underscore.to_sym || 404)
          end

          def standard_permission_denied_error
            error!({ message: "Unauthorized!"}, 401)
          end

          def presenter collection, options={}
            presenter_name = options.delete(:presenter_name) || get_context_presenter_name #self.try(:class_context).try(:presenter_name)
            if collection.is_a?(ActiveRecord::Relation)
              options[:meta]= pagination_info
              presenter_name ||= default_presenter_class(collection.model)
            elsif collection.is_a?(ActiveRecord::Base)
              presenter_name ||= default_presenter_class(collection.class)
            end
            ver = version.try(:upcase)
            begin
              presenter_class = "::#{get_context_engine_namespace}::Grape::#{ver ? "#{ver}::" : ""}Presenters::#{presenter_name}".constantize
            rescue NameError
              begin
                presenter_class = "::#{get_context_engine_namespace}::#{ver ? "#{ver}::" : ""}::Presenters::#{presenter_name.demodulize}".constantize
              rescue NameError
                presenter_class = presenter_name.constantize
              end
            end
            raise ArgumentError, "#{presenter_class} should be subclass of #{::Grape::Entity}." unless presenter_class && presenter_class.ancestors.include?(::Grape::Entity)
            present collection, with: presenter_class, meta: options[:meta], root: options[:root], locals: options[:locals], only: options[:only], except: options[:except]
          end

          def direct_present object, options={}
            with = options.delete(:with)
            if object.respond_to?(:map)
              object.map { |obj| with.new(obj) }
            else
              with.new(object)
            end
          end

          #
          # @Override from Grape::DSL::InsideRoute
          #
          def present *args
            options = args.count > 1 ? args.extract_options! : {}
            key, object = if args.count == 2 && args.first.is_a?(Symbol)
                            args
                          else
                            [nil, args.first]
                          end
            entity_class = entity_class_for_obj(object, options)

            root = options.delete(:root)
            meta = options.delete(:meta)

            representation = if entity_class
                              entity_representation_for(entity_class, object, options)
                            else
                              object
                            end

            representation = { root => representation } if root

            # if representation.is_a?(Array) and parameters.present?
            #   representation = { data: representation }
            # end
            if representation.is_a?(Hash) && meta.present?
              representation = representation.merge!({meta: meta})
            end
            if key
              representation = (@body || {}).merge(key => representation)
            elsif entity_class.present? && @body
              raise ArgumentError, "Representation of type #{representation.class} cannot be merged." unless representation.respond_to?(:merge)
              representation = @body.merge(representation)
            end

            body representation
          end

          def pagination_info
            hash = {}
            if header
              config = self.class.api_config.pagination.config
              hash[config.per_page] = header[config.per_page].to_i
              hash[config.page] = header[config.page].to_i if config.page
              if config.include_total
                hash[config.total] = header[config.total].to_i
                if hash[config.per_page].to_i > 0
                  hash["Total-Pages"] = (hash[config.total].to_f / hash[config.per_page]).ceil
                  if hash[config.page]
                    hash["Last-Page"] = hash[config.page] >= hash["Total-Pages"]
                  end
                end
              end
              hash
            end
          end

        end

        module ClassMethods

          def set_presenter presenter=nil, &block
            if block_given?
              self.presenter_name= block
            else
              self.presenter_name = presenter
            end
          end

        end
      end
    end
  end
end