require 'spec_helper'

describe ActiveTriples::RDFSource do
  let(:dummy_source) { Class.new { include ActiveTriples::RDFSource } }

  subject { source_class.new }

  describe ".apply_schema" do
    before do
      class MyDataModel < ActiveTriples::Schema
        property :test_title, :predicate => RDF::DC.title
      end
    end
    after do
      Object.send(:remove_const, "MyDataModel")
    end
    it "should apply the schema" do
      dummy_source.apply_schema MyDataModel

      expect{dummy_source.new.test_title}.not_to raise_error
    end
  end
end
