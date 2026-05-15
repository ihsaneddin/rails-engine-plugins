module Plugins
  module Controllers
    module Concerns
      module Responder

        extend ActiveSupport::Concern

        included do
          include ::Plugins::Decorators.inheritables.class_attributes
          inheritable_class_attribute :presenter_class
          rescue_from ActiveRecord::RecordNotFound do |e|
            present_error "Record not found", 404
          end
          class_attribute :engine_namespace
          self.engine_namespace = self.name.split("::")[0]
        end

        def engine_namespace
          self.class.name.split("::")[0]
        end

        def present_error message = "Error", status = 500
          render json: { message: message }, status: status
        end

        def present data, *args
          params = args.extract_options!
          pagination = params.delete :pagination
          presenter = params.delete :presenter
          presenter = presenter.nil?? presenter_class_constant.new(data, params: params) : presenter.new(data, params: params)
          presenter = pagination ? presenter.serialize(meta: pagination) : presenter.serialize
          render json: presenter
        end

        def presenter_class_constant
          unless defined? Alba::Resource
            raise "Please install alba gem"
          end
          @presenter_class_constant ||= resolve_presenter_class(presenter_klass)
          raise ArgumentError, "#{presenter_klass} should implement of #{Alba::Resource}." unless @presenter_class_constant && @presenter_class_constant.include?(Alba::Resource)
          @presenter_class_constant
        end

        def presenter_klass
          get_value(:presenter).presence || self.class.presenter_class.presence || get_context_presenter_name || default_presenter_class
        end

        def default_presenter_class
          controller_name.classify
        end

        def get_context_presenter_name
          p_name = nil
          if model_class_constant&.respond_to?(:api_resource?) && model_class_constant.api_resource?
            mod = model_class_constant
            ctx = get_value(:resource_context)
            if cfg = mod.api_resource_of(ctx)
              if cfg.use_api_evaluation
                cfg.with_context(self) do
                  p_name = cfg.presenter
                end
              else
                p_name = cfg.presenter
              end
            end
          end
          p_name
        end

        def get_context_engine_namespace
          ctx_name = self.class.name
          if ctx_name.blank? && respond_to?(:api_config)
            api_ns = api_config&.base_api_namespace
            ctx_name = api_ns if api_ns.present?
          end
          ctx_name ||= self.class.superclass&.name
          ctx_name&.split("::")&.first
        end

        def presenter_candidates(name)
          presenter_name = name.to_s
          demodulized_name = presenter_name.demodulize
          candidates = [presenter_name]
          engine = get_context_engine_namespace

          if engine.present? && !presenter_name.include?('::')
            candidates << "::#{engine}::Controllers::Presenters::#{demodulized_name}"
            candidates << "::#{engine}::Presenters::#{demodulized_name}"
          end

          candidates.uniq
        end

        def resolve_presenter_class(name)
          return name if name.is_a?(Class)

          presenter_candidates(name).each do |candidate|
            klass = candidate.safe_constantize
            return klass if klass
          end

          nil
        end

        class_methods do

          def set_presenter_class klass
            self.presenter_class = klass
          end

        end

      end
    end
  end
end
