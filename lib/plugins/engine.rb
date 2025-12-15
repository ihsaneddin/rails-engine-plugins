# require 'plugins/configuration/bus'
require 'plugins/engine_callbacks'
module Plugins
  class Engine < ::Rails::Engine
    isolate_namespace Plugins

    extend ::Plugins::EngineCallbacks

    config.after_initialize do
      #Rails.application.eager_load! unless Rails.configuration.eager_load
      ::Plugins::Configuration::Bus.apply_setup!
      # ::Plugins::Models::Concerns::Eventable::PublishesEvents.eventable_register_events
      # ::Plugins::Models::Concerns::Eventable::SubscribesToEvents.eventable_register_event_buses!
    end

    config.to_prepare do
       Dir.glob(Rails.root.join("app/subscribers/**/*.rb")).each do |file|
        require file rescue nil
      end
      ::Plugins.config.load_constants!
    end

  end
end
