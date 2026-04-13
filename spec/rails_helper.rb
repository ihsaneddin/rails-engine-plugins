ENV["RAILS_ENV"] ||= "test"

require_relative "spec_helper"
require "logger"

unless defined?(Rails) && Rails.application&.initialized?
  require File.expand_path("dummy/config/environment", __dir__)
end
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "factory_bot_rails"

Dir[Plugins::Engine.root.join("spec/support/**/*.rb")].sort.each { |f| require f }
Dir[Plugins::Engine.root.join("spec/dummy/lib/**/*.rb")].sort.each { |f| require f }
Dir[Plugins::Engine.root.join("spec/dummy/app/subscribers/**/*.rb")].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::NoDatabaseError => e
  warn "Database not available: #{e.message}"
end

FactoryBot.definition_file_paths = [Plugins::Engine.root.join("spec/factories").to_s]
FactoryBot.find_definitions

RSpec.configure do |config|
  config.fixture_path = File.expand_path("fixtures", __dir__)
  config.include FactoryBot::Syntax::Methods
  config.use_transactional_fixtures = false

  if defined?(DatabaseCleaner)
    config.before(:suite) do
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean_with(:truncation)
    end

    config.around(:each) do |example|
      DatabaseCleaner.cleaning do
        example.run
      end
    end
  end

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
