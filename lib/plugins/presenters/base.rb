require 'alba'

module Plugins
  module Presenters
    class Base

      include Alba::Resource

      root_key :data, :data

    end
  end
end