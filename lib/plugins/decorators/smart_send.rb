module Plugins
  module Decorators
    module SmartSend

      extend ActiveSupport::Concern

      def smart_send(method_name, args = nil)
        args_list = args.nil? ? [] : args
        args_list = [args_list] unless args_list.is_a?(Array)
        args_list = args_list.dup

        method = self.method(method_name)
        params = method.parameters

        keyword_names = params.select { |type, _| type == :keyreq || type == :key }.map(&:last)
        has_keyrest = params.any? { |type, _| type == :keyrest }
        provided_kwargs = {}
        if args_list.last.is_a?(Hash) && (has_keyrest || (args_list.last.keys & keyword_names).any?)
          provided_kwargs = args_list.pop.dup
        end

        fixed_args = []
        splat_args = []
        keyword_args = {}

        params.each_with_index do |(type, name), i|
          case type
          when :req
            fixed_args << (i < args_list.length ? args_list[i] : nil)
          when :opt
            fixed_args << args_list[i] if i < args_list.length
          when :rest
            splat_args = i < args_list.length ? args_list[i..] : []
            break
          when :keyreq
            if provided_kwargs.key?(name)
              keyword_args[name] = provided_kwargs[name]
            elsif i < args_list.length
              keyword_args[name] = args_list[i]
            else
              keyword_args[name] = nil
            end
          when :key
            if provided_kwargs.key?(name)
              keyword_args[name] = provided_kwargs[name]
            elsif i < args_list.length
              keyword_args[name] = args_list[i]
            end
          when :keyrest
            hash_args = provided_kwargs
            hash_args = args_list[i] if hash_args.empty? && i < args_list.length
            keyword_args.merge!(hash_args) if hash_args.is_a?(Hash)
            break
          end
        end

        if keyword_args.any?
          send(method_name, *fixed_args, *splat_args, **keyword_args)
        else
          send(method_name, *fixed_args, *splat_args)
        end
      end

    end
  end
end

# module Plugins
#   module Decorators
#     module SmartSend

#       extend ActiveSupport::Concern

#       def smart_send(method_name, args = nil)
#         fixed_args, splat_args, keyword_args = ArgumentBuilder.build(self, method_name, args)

#         if keyword_args.any?
#           send(method_name, *fixed_args, *splat_args, **keyword_args)
#         else
#           send(method_name, *fixed_args, *splat_args)
#         end
#       end

#       def self.smart_send(method_name, args = nil)
#         fixed_args, splat_args, keyword_args = ArgumentBuilder.build(self, method_name, args)

#         if keyword_args.any?
#           send(method_name, *fixed_args, *splat_args, **keyword_args)
#         else
#           send(method_name, *fixed_args, *splat_args)
#         end
#       end

#       module ArgumentBuilder
#         module_function

#         def build(target, method_name, args)
#           method = target.method(method_name)
#           params = method.parameters

#           args_list = args.nil? ? [] : args
#           args_list = [args_list] unless args_list.is_a?(Array)
#           args_list = args_list.dup

#           wants_keywords = params.any? { |type, _| type == :keyreq || type == :key || type == :keyrest }
#           provided_kwargs = {}
#           if wants_keywords && args_list.last.is_a?(Hash)
#             provided_kwargs = args_list.pop.dup
#           end

#           fixed_args = []
#           splat_args = []
#           keyword_args = {}
#           processed_keys = []
#           index = 0

#           params.each do |type, name|
#             case type
#             when :req
#               fixed_args << (index < args_list.length ? args_list[index] : nil)
#               index += 1
#             when :opt
#               if index < args_list.length
#                 fixed_args << args_list[index]
#                 index += 1
#               end
#             when :rest
#               splat_args = index < args_list.length ? args_list[index..] : []
#               index = args_list.length
#             when :keyreq
#               keyword_args[name] = provided_kwargs.key?(name) ? provided_kwargs[name] : nil
#               processed_keys << name
#             when :key
#               keyword_args[name] = provided_kwargs[name] if provided_kwargs.key?(name)
#               processed_keys << name
#             when :keyrest
#               remaining = provided_kwargs.reject { |k, _| processed_keys.include?(k) }
#               keyword_args.merge!(remaining) if remaining.any?
#             end
#           end

#           [fixed_args, splat_args, keyword_args]
#         end
#       end

#       private_constant :ArgumentBuilder

#     end
#   end
# end
