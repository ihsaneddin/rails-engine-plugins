# require 'plugins/configuration/bus'
module Plugins
  class Engine < ::Rails::Engine
    isolate_namespace Plugins

    initializer 'plugins.pub_sub' do |app|
      app.reloader.to_prepare do
        ::Plugins::Configuration::Bus.apply_setup!
        ::Plugins::Models::Concerns::Eventable::PublishesEvents.eventable_register_events
        ::Plugins::Models::Concerns::Eventable::SubscribesToEvents.eventable_register_event_buses!
      end
    end

  end
end
