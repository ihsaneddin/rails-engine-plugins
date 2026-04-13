require "spec_helper"
require "active_support/all"
require File.expand_path("../../../lib/plugins/decorators", __dir__)
require File.expand_path("../../../lib/plugins/decorators/smart_send", __dir__)
require File.expand_path("../../../lib/plugins/decorators/inheritables", __dir__)
require File.expand_path("../../../lib/plugins/models/concerns/options", __dir__)
require File.expand_path("../../../lib/plugins/decorators/method_annotations", __dir__)
require File.expand_path("../../dummy/lib/dummy/plugins/decorators/support", __dir__)

RSpec.describe Plugins::Decorators::MethodAnnotations do
  let(:host_class) { Dummy::PluginsDecoratorsSupport::MethodAnnotationsHost }

  it "stores annotations per method" do
    expect(host_class.annotations_for(:publish)).to eq(event: :created, tags: %i[a b])
  end

  it "finds methods annotated with a key or specific value" do
    expect(host_class.methods_annotated_with(:event)).to include(:publish)
    expect(host_class.methods_annotated_with(:tags, :a)).to include(:publish)
    expect(host_class.method_annotated_with?(:publish, :tags, :b)).to eq(true)
  end

  it "clears annotations selectively with annotate_method!" do
    host_class.annotate_method(:archive, event: :archived)
    host_class.annotate_method!(:publish, event: :updated)

    expect(host_class.annotations_for(:publish)).to eq(event: :updated, tags: %i[a b])
    expect(host_class.annotations_for(:archive)).to eq({})
  end
end
