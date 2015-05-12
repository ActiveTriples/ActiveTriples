require 'spec_helper'

RSpec.describe ActiveTriples::Configuration do
  subject { described_class.new(starting_hash) }
  let(:starting_hash) { {} }
  describe "[]" do
    context "with bad config values" do
      let(:starting_hash) { {:bad => 1} }
      it "should not return them" do
        expect(subject[:bad]).to be_nil
      end
    end
    context "with good config values" do
      let(:starting_hash) { {:type => 1} }
      it "should return them" do
        expect(subject[:type]).to eq 1
      end
    end
  end

  describe "to_h" do
    context "with bad and good config" do
      let(:starting_hash) do
        {
          :bad => 1,
          :type => 2
        }
      end
      it "should return only good ones" do
        expect(subject.to_h).to eq ({:type => 2})
      end
    end
  end

  describe "#merge" do
    let(:starting_hash) do
      {
        :rdf_label => RDF::SKOS.prefLabel,
        :type => RDF::RDFS.Class
      }
    end
    it "should override some values" do
      new_hash = {:rdf_label => RDF::RDFS.label}
      expect(subject.merge(new_hash)[:rdf_label]).to eq RDF::RDFS.label
    end
    it "should merge type" do
      new_hash = {:type => RDF::RDFS.Container}
      expect(subject.merge(new_hash)[:type]).to eq [RDF::RDFS.Class, RDF::RDFS.Container]
    end
  end
end
