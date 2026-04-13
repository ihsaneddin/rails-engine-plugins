require "spec_helper"
require File.expand_path("../../lib/plugins/errors", __dir__)

RSpec.describe Plugins::Errors do
  it "defines authentication and authorization errors as StandardError subclasses" do
    expect(described_class::AuthenticationError).to be < StandardError
    expect(described_class::AuthorizationError).to be < StandardError
    expect(described_class::ApiAuthenticationError).to be < StandardError
    expect(described_class::ApiAuthorizationError).to be < StandardError
    expect(described_class::UnsupportedAdapterError).to be < StandardError
  end
end
