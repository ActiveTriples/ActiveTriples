require 'spec_helper'

RSpec.describe ActiveTriples::Property do
  subject { described_class.new(options) }
  let(:options) do
    {
      :name => :title,
      :predicate => RDF::DC.title,
      :class_name => "Test"
    }
  end

  it "should create accessors for each passed option" do
    expect(subject.name).to eq :title
    expect(subject.predicate).to eq RDF::DC.title
    expect(subject.class_name).to eq "Test"
  end

  describe "#to_h" do
    it "should not return the property's name" do
      expect(subject.to_h).to eq (
        {
          :predicate => RDF::DC.title,
          :class_name => "Test"
        }
      )
    end
  end
end
