require 'spec_helper'

  describe 'reciprocal relationships' do
    before do
      class DummyPerson
        include ActiveTriples::RDFSource
        configure :type => RDF::URI('http://example.org/Person')
        property :foaf_name, :predicate => RDF::FOAF.name
        property :publications, :predicate => RDF::FOAF.publications, :class_name => 'DummyDocument'
        property :knows, :predicate => RDF::FOAF.knows, :class_name => DummyPerson
      end

      class DummyDocument
        include ActiveTriples::RDFSource
        configure :type => RDF::URI('http://example.org/Document')
        property :title, :predicate => RDF::DC.title
        property :creator, :predicate => RDF::DC.creator, :class_name => 'DummyPerson'
      end
    end

    after do
      Object.send(:remove_const, "DummyDocument")
      Object.send(:remove_const, "DummyPerson")
    end

    let (:document1) do
      d = DummyDocument.new
      d.title = 'Document One'
      d
    end

    let (:person1) do
      p = DummyPerson.new
      p.foaf_name = 'Alice'
      p
    end

    it 'should allow access to deep nodes' do
      document1.creator = person1
      expect(document1.creator).to eq [person1]
      person1.publications = document1
      expect(person1.publication).to eq [document1]
    end
  end
