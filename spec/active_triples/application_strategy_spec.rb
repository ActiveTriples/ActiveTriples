require 'spec_helper'

RSpec.describe ActiveTriples::ApplicationStrategy do
  subject { described_class }

  describe ".apply" do
    it "should copy the property to the asset" do
      asset = build_asset
      property = build_property("name", {:predicate => RDF::DC.title})

      subject.apply(asset, property)

      expect(asset).to have_received(:property).with(property.name, property.to_h)
    end

    def build_asset
      object_double(ActiveTriples::Resource, :property => nil)
    end

    def build_property(name, options)
      property = object_double(ActiveTriples::Property.new(:name => nil))
      allow(property).to receive(:name).and_return(name)
      allow(property).to receive(:to_h).and_return(options)
      property
    end
  end
end
