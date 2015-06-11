require 'spec_helper'

RSpec.describe ActiveTriples::Schema do
  subject { described_class }

  describe ".property" do
    it "should define a property" do
      subject.property :title, :predicate => RDF::DC.title

      property = subject.properties.first
      expect(property.name).to eq :title
      expect(property.predicate).to eq RDF::DC.title
    end
  end
end
