module Plugins
  module Errors
    class ApiAuthenticationError < StandardError
    end
    class ApiAuthorizationError < StandardError
    end
    class UnsupportedAdapterError < StandardError
    end
  end
end