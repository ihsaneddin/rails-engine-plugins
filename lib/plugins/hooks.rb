begin; require 'grape'; rescue LoadError; end
if defined?(Grape::API)
  require 'plugins/grape'

  klass = if Grape::VERSION >= '1.2.0' || defined?(Grape::API::Instance)
    Grape::API::Instance
  else
    Grape::API
  end

  #klass.send(:include, Plugins::Grape)
end