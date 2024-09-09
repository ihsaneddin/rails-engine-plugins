require_relative "lib/plugins/version"

Gem::Specification.new do |spec|
  spec.name        = "plugins"
  spec.version     = Plugins::VERSION
  spec.authors     = ["ihsaneddin"]
  spec.email       = ["ihsaneddin@gmail.com"]
  spec.homepage    = "https://github.com/ihsaneddin"
  spec.summary     = "Summary of Plugins."
  spec.description = "Description of Plugins."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  #spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ihsaneddin/engine-plugins"
  spec.metadata["changelog_uri"] = "https://github.com/ihsaneddin/engine-plugins"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.1"
  spec.add_dependency 'alba'
  spec.add_dependency 'options_model'
  spec.add_dependency "activeentity", ">= 6.1.0"
end
