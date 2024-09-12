module Plugins
  module Controllers
    module Concerns
      autoload :Authenticate, 'plugins/controllers/concerns/authenticate'
      autoload :Resourceful, 'plugins/controllers/concerns/resourceful'
      autoload :Paginated, 'plugins/controllers/concerns/paginated'
      autoload :Responder, 'plugins/controllers/concerns/responder'
    end
  end
end