require 'spec_helper'

describe ActiveTriples::RDFSource do

  let(:source_class) { Class.new { include ActiveTriples::RDFSource } }
  let(:uri) { RDF::URI('http://example.org/moomin') }

  subject { source_class.new }

  describe '#==' do

    shared_examples 'Term equality' do
      it 'equals itself' do
        expect(subject).to eq subject
      end

      it 'equals its clone' do
        expect(subject).to eq source_class.new(subject.rdf_subject)
      end

      it 'does not equal another term' do
        expect(subject).not_to eq RDF::Node.new
      end

      it 'does not equal another term' do
        expect(subject).not_to eq source_class.new
      end
    end

    include_examples 'Term equality'

    context 'with a URI' do
      include_examples 'Term equality' do
        subject { source_class.new(uri) }
      end
    end
  end

  describe ".apply_schema" do
    let(:dummy_source) { Class.new { include ActiveTriples::RDFSource } }

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
