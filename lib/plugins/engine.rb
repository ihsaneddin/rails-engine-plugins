require 'plugins/configuration/bus'
module Plugins
  class Engine < ::Rails::Engine
    isolate_namespace Plugins

    initializer 'plugins.pub_sub' do |app|
      app.reloader.to_prepare do
        ::Plugins::Configuration::Bus.apply_setup!
      end
    end

  end
end
