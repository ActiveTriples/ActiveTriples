require 'spec_helper'

describe ActiveTriples::RDFSource do
  let(:source_class) { Class.new { include ActiveTriples::RDFSource } }

  subject { source_class.new }

  describe "#fetch" do
    it "passes extra arguments to RDF::Reader" do
      expect(RDF::Reader).to receive(:open).with(subject.rdf_subject,
                                                 { base_uri: subject.rdf_subject,
                                                   headers: { Accept: 'x-humans/as-they-are' } })
      subject.fetch(headers: { Accept: 'x-humans/as-they-are' })
    end
  end

  describe ".apply_schema" do
    before do
      class MyDataModel < ActiveTriples::Schema
        property :test_title, :predicate => RDF::DC.title
      end
    end
    after do
      Object.send(:remove_const, "MyDataModel")
    end
    it "applies the schema" do
      source_class.apply_schema MyDataModel

      expect { source_class.new.test_title }.not_to raise_error
    end
  end
end
