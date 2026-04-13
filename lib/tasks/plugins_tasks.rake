# desc "Explaining what the task does"
# task :plugins do
#   # Task goes here
# end
namespace :plugins do
  desc "Grape api routes"
  task grape_routes: :environment do
    klass = Plugins.config.grape_api.base_api_class.constantize rescue nil
    if klass
      klass.routes.each do |api|
        method = api.request_method.ljust(10) if api.request_method
        path = api.path.gsub ":version", api.version if api.version
        puts "    #{method} #{path}"
      end
    else
      puts "No base api class defined"
    end
  end
end