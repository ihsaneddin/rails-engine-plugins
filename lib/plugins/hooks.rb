begin; require 'grape'; rescue LoadError; end
if defined?(Grape::API)
  require 'plugins/grape'

  klass = if Grape::VERSION >= '1.2.0' || defined?(Grape::API::Instance)
    Grape::API::Instance
  else
    Grape::API
  end
  # Install before including Plugins::Grape because that inclusion defines API
  # methods which can trigger the affected Grape lifecycle interception.
  Plugins::Grape.install_add_setup_guard(Grape::API)
  Grape::API.send(:include, Plugins::Grape)
end
