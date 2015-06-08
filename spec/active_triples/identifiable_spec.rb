require 'spec_helper'
require 'active_model'

describe ActiveTriples::Identifiable do
  before do
    class ActiveExample; include ActiveTriples::Identifiable; end
  end

  after do
    Object.send(:remove_const, 'ActiveExample')
  end

  subject { ActiveExample.new }
  let(:klass) { ActiveExample }

  shared_context 'with data' do
    let(:parent) { MyResource.new }

    before do
      class MyResource
        include ActiveTriples::RDFSource
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

        def self.property(*args)
          prop = args.first

          define_method prop.to_s do
            resource.get_values(prop)
          end

          define_method "#{prop.to_s}=" do |*args|
            resource.set_value(prop, *args)
          end

          resource_class.property(*args)
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

      context 'with other identifiable classes' do
        before do
          class ActiveExampleTwo
            include ActiveTriples::Identifiable
          end
        end
        after do
          Object.send(:remove_const, 'ActiveExampleTwo')
        end

        it 'does not effect other classes' do
          klass.property :identifier, :predicate => RDF::DC.identifier
          expect(ActiveExampleTwo.properties).to be_empty
        end
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
        
        it "persists its triples down" do
          expect(parent.statements.to_a).to include *parent.relation.first.resource.statements.to_a
        end

        context "when using a different persistance strategy" do
          let(:fake_strategy_factory) do 
            s = class_double(ActiveTriples::ParentStrategy)
            allow(s).to receive(:new).and_return(fake_strategy)
            s
          end
          let(:fake_strategy) do
            instance_double(ActiveTriples::ParentStrategy)
          end
          subject do
            s = ActiveExample.new
            s.resource.set_persistence_strategy(fake_strategy_factory)
            s
          end
          it "should not persist the triples down" do
            expect(parent.statements.to_a).not_to include *parent.relation.first.resource.statements.to_a
          end
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
