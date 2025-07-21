module Plugins
  module Decorators
    module SmartSend

      extend ActiveSupport::Concern

      def smart_send(method_name, args)
        method = self.method(method_name)
        params = method.parameters

        fixed_args = []
        splat_args = []
        keyword_args = {}

        params.each_with_index do |(type, name), i|
          case type
          when :req, :opt
            fixed_args << args[i] || nil
          when :rest
            splat_args = args[i..] || []
            break
          when :keyreq, :key
            keyword_args[name] = args[i] || nil
          when :keyrest
            # convert remaining args into keyword hash (assumes they are pairs)
            hash_args = args[i] || {}
            keyword_args.merge!(hash_args)
            break
          end
        end

        if keyword_args.any?
          self.send(method_name, *fixed_args, *splat_args, **keyword_args)
        else
          self.send(method_name, *fixed_args, *splat_args)
        end
      end

    end
  end
end