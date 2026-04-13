module Plugins
  module Errors
    class AuthenticationError < StandardError
    end
    class AuthorizationError < StandardError
    end
    class ApiAuthenticationError < StandardError
    end
    class ApiAuthorizationError < StandardError
    end
    class UnsupportedAdapterError < StandardError
    end
  end
end