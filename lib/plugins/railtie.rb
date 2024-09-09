module Plugins
  class Railtie < ::Rails::Railtie

    initializer 'plugins.initialize' do

      ActiveSupport.on_load(:active_record) do
        include Plugins::Models
      end
      ActiveSupport.on_load(:action_controller) do
        include Plugins::Controllers
      end

    end

  end
end
