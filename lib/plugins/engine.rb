# require 'plugins/configuration/bus'
module Plugins
  class Engine < ::Rails::Engine
    isolate_namespace Plugins

    config.after_initialize do
      #Rails.application.eager_load! unless Rails.configuration.eager_load
      ::Plugins::Configuration::Bus.apply_setup!
      # ::Plugins::Models::Concerns::Eventable::PublishesEvents.eventable_register_events
      # ::Plugins::Models::Concerns::Eventable::SubscribesToEvents.eventable_register_event_buses!
    end

  end
end
