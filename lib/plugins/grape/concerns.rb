module Plugins
  module Grape
    module Concerns
      autoload :Authenticate, 'plugins/grape/concerns/authenticate'
      autoload :Resourceful, 'plugins/grape/concerns/resourceful'
      autoload :Paginated, 'plugins/grape/concerns/paginated'
      autoload :Responder, 'plugins/grape/concerns/responder'
    end
  end
end