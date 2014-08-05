require 'spec_helper'
require 'active_model'

describe ActiveTriples::Identifiable do
  before do
    class ActiveExample
      include ActiveTriples::Identifiable
    end
  end

  after do
    Object.send(:remove_const, 'ActiveExample')
  end

  subject { ActiveExample.new }
  let(:klass) { ActiveExample }

  shared_context 'with data' do
    let(:parent) { MyResource.new }

    before do
      class MyResource < ActiveTriples::Resource
        property :relation, predicate: RDF::DC.relation, class_name: 'ActiveExample'
      end

      klass.property :title, predicate: RDF::DC.title
      klass.property :identifier, predicate: RDF::DC.identifier
      klass.property :description, predicate: RDF::DC.description

      subject.resource.title = 'Moomin Valley in November'
      subject.resource.identifier = 'moomvember'
      subject.resource.description = 'The ninth and final book in the Moomin series by Finnish author Tove Jansson'
      parent.relation = subject
    end

    after do
      Object.send(:remove_const, 'MyResource')
    end
  end

  context 'without implementation' do
    describe '::from_uri' do
      it 'raises a NotImplementedError' do
       expect{ klass.from_uri(RDF::URI('http://example.org/blah')) }.to raise_error NotImplementedError 
      end
    end

    describe '#to_uri' do
      it 'raises a NotImplementedError' do
       expect{ subject.to_uri }.to raise_error NotImplementedError
      end
    end
  end
    
  context 'with implementation' do
    before do
      class ActiveExample
        attr_accessor :id
        configure base_uri: 'http://example.org/ns/'

        def self.from_uri(uri, *args)
          item = self.new
          item.parent = args.first unless args.empty? or args.first.is_a?(Hash)
          item
        end
      end

      subject.id = '123'
    end
    
    describe '::properties' do
      before do
        klass.property :title, :predicate => RDF::DC.title
      end
      it 'can be set' do
        expect(klass.properties).to include 'title'
      end

      it 'does not effect other classes' do
        class ActiveExampleTwo
          include ActiveTriples::Identifiable
        end
        klass.property :identifier, :predicate => RDF::DC.identifier
        expect(ActiveExampleTwo.properties).to be_empty
      end

      it 'sets property values' do
        subject.title = 'Finn Family Moomintroll'
        expect(subject.resource.title).to eq ['Finn Family Moomintroll']
      end

      it 'appends property values' do
        subject.title << 'Finn Family Moomintroll'
        expect(subject.resource.title).to eq ['Finn Family Moomintroll']
      end
      
      it 'returns correct values in property getters' do
        subject.resource.title = 'Finn Family Moomintroll'
        expect(subject.title).to eq subject.resource.title
      end
    end

    describe '::configure' do
      it 'allows configuration' do
        klass.configure type: RDF::OWL.Thing
        expect(subject.resource.type).to eq [RDF::OWL.Thing]
      end
    end

    describe '#parent' do
      it 'is nil' do
        expect(subject.parent).to be_nil
      end

      context 'with relationships' do
        include_context 'with data'
        
        it 'has a parent' do
          expect(parent.relation.first.parent).to eq parent
        end
        
        it 'has a parent after reload' do
          parent.relation.node_cache = {}
          expect(parent.relation.first.parent).to eq parent
        end
      end
    end
    
    describe '#rdf_subject' do
      it 'has a subject' do
        expect(subject.rdf_subject).to eq 'http://example.org/ns/123'
      end
    end

    describe '#to_uri' do
      it 'has a subject' do
        expect(subject.rdf_subject).to eq 'http://example.org/ns/123'
      end
    end
  end
end
