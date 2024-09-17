module Plugins
  module Controllers
    module Concerns
      module Responder

        extend ActiveSupport::Concern

        included do
          class_attribute :presenter_class
          class_attribute :presenter_proc
          rescue_from ActiveRecord::RecordNotFound do |e|
            present_error "Record not found", 404
          end

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
          @presenter_class_constant ||= presenter_klass.safe_constantize
          raise ArgumentError, "#{presenter_klass} should implement of #{Alba::Resource}." unless @presenter_class_constant && @presenter_class_constant.include?(Alba::Resource)
          @presenter_class_constant
        end

        def presenter_klass
          self.class.presenter_class.blank? ? default_presenter_class : self.class.presenter_class
        end

        def default_presenter_class
          default = self.class.name.gsub("#{Plugins.config.engine_namespace}::", "")
          default = default.split("::")
          default.pop
          default << controller_name.classify
          default.unshift(Plugins.config.engine_namespace, "Controllers", "Presenters")
          default.join("::")
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