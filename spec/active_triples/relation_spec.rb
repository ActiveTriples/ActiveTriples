# frozen_string_literal: true
require 'spec_helper'
require 'rdf/isomorphic'

describe ActiveTriples::Relation do
  let(:parent_resource) { double("parent resource", reflections: {}) }
  let(:value_args) { double("value args", last: {}) }

  let(:uri) { RDF::URI('http://example.org/moomin') }

  subject { described_class.new(parent_resource,  value_args) }

  shared_context 'with URI property' do
    subject { described_class.new(parent_resource, [property] ) }
    let(:property) { uri }
  end

  shared_context 'with symbol property' do
    subject { described_class.new(parent_resource, [property] ) }
    let(:property) { :moomin }
    let(:reflections) do 
      Class.new do
        include ActiveTriples::RDFSource
        property :moomin, predicate: RDF::URI('http://example.org/moomin')
      end
    end
    
    before do
      allow(parent_resource).to receive(:reflections).and_return(reflections)
    end
  end

  shared_context 'with unregistered property' do
    subject { described_class.new(parent_resource, [property] ) }
    let(:property) { :moomin }
    let(:reflections) { Class.new { include ActiveTriples::RDFSource } }
    
    before do
      allow(parent_resource).to receive(:reflections).and_return(reflections)
    end
  end

  describe '#build' do
    include_context 'with symbol property'

    let(:parent_resource) { ActiveTriples::Resource.new }

    it 'returns a new child node' do
      expect(subject.build).to be_a ActiveTriples::RDFSource
    end

    it 'adds new child node to relation' do
      expect { subject.build }.to change { subject.count }.by(1)
    end

    it 'builds child as new blank node by default' do
      expect(subject.build).to be_node
    end

    it 'builds child with uri if given' do
      uri = 'http://example.com/moomin'
      expect(subject.build(id: uri)).to be_uri
    end
    
    context 'with configured properties' do
      include_context 'with symbol property' do
        before do 
          reflections.property :moomin,
                               predicate:  RDF::Vocab::DC.relation,
                               class_name: 'WithTitle'
          class WithTitle
            include ActiveTriples::RDFSource
            property :title, predicate: RDF::Vocab::DC.title
          end
        end

        after { Object.send(:remove_const, :WithTitle) }
      end

      it 'sets attributes for built node' do
        attributes = { title: 'moomin' }
        
        expect(subject.build(attributes))
          .to have_attributes(title: ['moomin'])
      end
    end
  end

  describe '#delete' do
    include_context 'with symbol property'

    let(:parent_resource) { ActiveTriples::Resource.new }

    it 'handles a non-existent value' do
      expect { subject.delete(1) }.not_to change { subject.to_a }
    end

    context 'with values' do
      before { subject << values }

      let(:node) { RDF::Node.new(:node) }
      let(:uri) { RDF.Property }
      let(:values) { ['1', 1, :one, false, DateTime.now, node, uri] }

      it 'handles a non-existent value' do
        expect { subject.delete('blah') }.not_to change { subject.to_a }
      end

      it 'deletes a matched value' do
        expect { subject.delete(values.first) }
          .to change { subject.to_a }
               .to contain_exactly(*values[1..-1])
      end

      it 'deletes a URI value' do
        values.delete(uri)
        expect { subject.delete(uri) }
          .to change { subject.to_a }
               .to contain_exactly(*values)
      end

      it 'deletes a node value' do
        values.delete(node)
        expect { subject.delete(node) }
          .to change { subject.to_a }
               .to contain_exactly(*values)
      end

      it 'deletes a token value' do
        values.delete(:one)
        expect { subject.delete(:one) }
          .to change { subject.to_a }
               .to contain_exactly(*values)
      end
    end
  end

  describe '#delete?' do
    include_context 'with symbol property'

    let(:parent_resource) { ActiveTriples::Resource.new }

    it 'gives nil for non-existant value' do
      expect(subject.delete?(1)).to be_nil
    end

    it 'returns value when deleted' do
      subject.set(1)
      expect(subject.delete?(1)).to eq 1
    end

    it 'deletes existing values' do
      subject.set(1)
      expect { subject.delete?(1) }
        .to change { subject.to_a }.to be_empty
    end
  end

  describe '#subtract' do
    include_context 'with symbol property'

    let(:parent_resource) { ActiveTriples::Resource.new }
    
    it 'subtracts values as arguments' do
      subject.set([1,2,3])
      expect { subject.subtract(2,3) }
        .to change { subject.to_a }.to contain_exactly(1)
    end

    it 'subtracts values as an enumerable' do
      subject.set([1,2,3])
      expect { subject.subtract([2,3]) }
        .to change { subject.to_a }.to contain_exactly(1)
    end

    it 'subtracts token values' do
      subject.set([:one, :two, :three])
      expect { subject.subtract([:two, :three]) }
        .to change { subject.to_a }.to contain_exactly(:one)
    end
  end

  describe '#swap' do
    include_context 'with symbol property'

    let(:parent_resource) { ActiveTriples::Resource.new }
    
    it 'returns nil when the value is not present' do
      expect(subject.swap(1, 2)).to be_nil
    end

    it 'does not change contents for non-existent value' do
      expect { subject.swap(1, 2) }.not_to change { subject.to_a }
    end

    it 'swaps the value' do
      values = [1, 2, 3]
      subject.set(values)
      expect { subject.swap(1, 4) }
        .to change { subject.to_a }.to contain_exactly(2, 3, 4)
    end
  end

  describe '#clear' do
    include_context 'with symbol property'
    let(:parent_resource) { ActiveTriples::Resource.new }

    context 'with values' do
      before do
        subject.parent << [subject.parent.rdf_subject, 
                           subject.predicate, 
                           'moomin']
      end        

      it 'clears the relation' do
        expect { subject.clear }.to change { subject.result }
                                     .from(['moomin']).to([])
      end

      it 'deletes statements from parent' do
        query_pattern = [subject.parent.rdf_subject, subject.predicate, nil]

        expect { subject.clear }
          .to change { subject.parent.query(query_pattern) }.to([])
      end
    end
    
    it 'is a no-op when relation is empty' do
      subject.parent << [subject.parent.rdf_subject, RDF.type, 'moomin']
      expect { subject.clear }.not_to change { subject.parent.statements.to_a }
    end
  end

  describe '#<<' do
    include_context 'with symbol property'
    let(:parent_resource) { ActiveTriples::Resource.new }
    
    it 'adds a value' do
      expect { subject << :moomin }
        .to change { subject.to_a }.to contain_exactly(:moomin)
    end

    it 'adds multiple values' do
      values = [:moomin, :snork]
      expect { subject << values }
        .to change { subject.to_a }.to contain_exactly(*values)
    end
  end

  describe "#predicate" do
    context 'when the property is an RDF::Term' do
      include_context 'with URI property'

      it 'returns the specified RDF::Term' do
        expect(subject.predicate).to eq uri
      end
    end

    context 'when the property is a symbol' do
      include_context 'with symbol property'

      it 'returns the reflected property' do
        expect(subject.predicate).to eq uri
      end
    end

    context 'when the symbol property is unregistered' do
      include_context 'with unregistered property'
      it 'returns nil' do
        expect(subject.predicate).to be_nil
      end
    end
  end
  
  describe "#property" do
    context 'when the property is an RDF::Term' do
      include_context 'with URI property'

      it 'returns the specified RDF::Term' do
        expect(subject.property).to eq property
      end
    end

    context 'when the property is a symbol' do
      include_context 'with symbol property'

      it 'returns the property symbol' do
        expect(subject.property).to eq property
      end
    end

    context 'when the symbol property is unregistered' do
      include_context 'with unregistered property'

      it 'returns the property symbol' do
        expect(subject.property).to eq property
      end
    end
  end

  describe '#first_or_create' do
    let(:parent_resource) { ActiveTriples::Resource.new }

    context 'with symbol' do
      include_context 'with symbol property'
      
      it 'creates a new node' do
        expect { subject.first_or_create }.to change { subject.count }.by(1)
      end

      it 'returns existing node if present' do
        node = subject.build
        expect(subject.first_or_create).to eq node
      end

      it 'does not create a new node when one exists' do
        subject.build
        expect { subject.first_or_create }.not_to change { subject.count }
      end

      it 'returns literal value if appropriate' do
        subject << literal = 'moomin'
        expect(subject.first_or_create).to eq literal
      end
    end
  end

  describe '#result' do
    context 'with nil predicate' do
      include_context 'with unregistered property'
      
      it 'is empty' do
        expect(subject.result).to contain_exactly()
      end
    end
    
    context 'with predicate' do
      include_context 'with symbol property' do
        let(:parent_resource) { ActiveTriples::Resource.new }
      end

      it 'is empty' do
        expect(subject.result).to contain_exactly()
      end

      context 'with values' do
        before do
          values.each do |value|
            subject.parent << [subject.parent.rdf_subject, uri, value]
          end
        end

        let(:values) { ['Comet in Moominland', 'Finn Family Moomintroll'] }
        let(:node) { RDF::Node.new }

        it 'contain values' do
          expect(subject.result).to contain_exactly(*values)
        end

        context 'with castable values' do
          let(:values) do
            [uri, RDF::URI('http://ex.org/too-ticky'), RDF::Node.new]
          end

          it 'casts Resource values' do
            expect(subject.result)
              .to contain_exactly(a_kind_of(ActiveTriples::Resource),
                                  a_kind_of(ActiveTriples::Resource),
                                  a_kind_of(ActiveTriples::Resource))
          end

          it 'cast values have correct URI' do
            expect(subject.result.map(&:rdf_subject))
              .to contain_exactly(*values)
          end

          context 'and persistence_strategy is configured' do
            before do
              reflections
                .property :moomin, 
                          predicate: RDF::URI('http://example.org/moomin'), 
                          persist_to: ActiveTriples::RepositoryStrategy
            end
            
            it 'assigns persistence strategy' do
              subject.result.each do |node|
                expect(node.persistence_strategy)
                  .to be_a ActiveTriples::RepositoryStrategy
              end
            end
          end
          
          context 'and #cast? is false' do
            let(:values) do
              [uri, RDF::URI('http://ex.org/too-ticky'), RDF::Node.new,
              'moomin', Date.today]
            end

            it 'does not cast results' do
              allow(subject).to receive(:cast?).and_return(false)
              expect(subject.result).to contain_exactly(*values)
            end
          end

          context 'when #return_literals? is true' do
            let(:values) do
              [RDF::Literal('moomin'), RDF::Literal(Date.today)]
            end

            it 'does not cast results' do
              allow(subject).to receive(:return_literals?).and_return(true)
              expect(subject.result).to contain_exactly(*values)
            end
          end
        end
      end
    end
  end

  describe "#rdf_subject" do
    let(:parent_resource) { double("parent resource", reflections: {}) }

    subject { described_class.new(parent_resource, double("value args") ) }

    context "when relation has 0 value arguments" do
      before { subject.value_arguments = double(length: 0) }

      it "should raise an error" do
        expect { subject.send(:rdf_subject) }.to raise_error ArgumentError
      end
    end

    context "when term has 1 value argument" do
      before do
        allow(subject.parent).to receive(:rdf_subject) { "parent subject" }
        subject.value_arguments = double(length: 1)
      end

      it "should call `rdf_subject' on the parent" do
        expect(subject.send(:rdf_subject) ).to eq "parent subject"
      end

      it " is a private method" do
        expect { subject.rdf_subject }.to raise_error NoMethodError
      end
    end

    context "when relation has 2 value arguments" do
      before { subject.value_arguments = double(length: 2, first: "first") }

      it "should return the first value argument" do
        expect(subject.send(:rdf_subject) ).to eq "first"
      end
    end

    context "when relation has 3 value arguments" do
      before { subject.value_arguments = double(length: 3) }

      it "should raise an error" do
        expect { subject.send(:rdf_subject) }.to raise_error ArgumentError
      end
    end
  end

  describe '#size' do
    context 'with predicate' do
      include_context 'with symbol property' do
        let(:parent_resource) { ActiveTriples::Resource.new }
      end

      context 'with values' do
        let(:values) { ['Comet in Moominland', 'Finn Family Moomintroll'] }
        before do
          values.each do |value|
            subject.parent << [subject.parent.rdf_subject, uri, value]
          end
        end
        it "returns the size of the result" do
          expect(subject.size).to eq 2
        end
      end
    end
  end

  describe '#set' do
    include_context 'with unregistered property'
    
    it 'raises UndefinedPropertyError' do
      expect { subject.set('x') }
        .to raise_error ActiveTriples::UndefinedPropertyError
    end

    context 'with predicate' do
      include_context 'with symbol property' do
        let(:parent_resource) { ActiveTriples::Resource.new }
      end

      it 'sets a value' do
        expect { subject.set(:moomin) }
          .to change { subject.to_a }.to contain_exactly(:moomin)
      end

      it 'sets mulitple values' do
        values = [:moomin, :snork]
        expect { subject.set(values) }
          .to change { subject.to_a }.to contain_exactly(*values)
      end

      context 'and persistence config' do
        before do
          reflections
            .property :moomin, 
                      predicate: RDF::URI('http://example.org/moomin'), 
                      persist_to: ActiveTriples::RepositoryStrategy
        end

        it 'returns values with persistence strategy set' do
          expect(subject.set(RDF::Node.new).map(&:persistence_strategy))
            .to contain_exactly(an_instance_of(ActiveTriples::RepositoryStrategy))
        end
      end
    end
  end

  describe '#join' do
    context 'with predicate' do
      include_context 'with symbol property' do
        let(:parent_resource) { ActiveTriples::Resource.new }
      end

      context 'with values' do
        let(:values) { ['Comet in Moominland', 'Finn Family Moomintroll'] }
        before do
          values.each do |value|
            subject.parent << [subject.parent.rdf_subject, uri, value]
          end
        end
        it "returns joined strings" do
          expect(subject.join(", ")).to eq "Comet in Moominland, Finn Family Moomintroll"
        end
      end
    end
  end

  describe "#valid_datatype?" do
    subject { described_class.new(double("parent", reflections: []), "value" ) }
    before { allow(subject.parent).to receive(:rdf_subject) { "parent subject" } }
    context "the value is not a Resource" do
      it "should be true if value is a String" do
        expect(subject.send(:valid_datatype?, "foo")).to be true
      end
      it "should be true if value is a Symbol" do
        expect(subject.send(:valid_datatype?, :foo)).to be true
      end
      it "should be true if the value is a Numeric" do
        expect(subject.send(:valid_datatype?, 1)).to be true
        expect(subject.send(:valid_datatype?, 0.1)).to be true
      end
      it "should be true if the value is a Date" do
        expect(subject.send(:valid_datatype?, Date.today)).to be true
      end
      it "should be true if the value is a Time" do
        expect(subject.send(:valid_datatype?, Time.now)).to be true
      end
      it "should be true if the value is a boolean" do
        expect(subject.send(:valid_datatype?, false)).to be true
        expect(subject.send(:valid_datatype?, true)).to be true
      end
    end

    context "the value is a Resource" do
      after { Object.send(:remove_const, :DummyResource) }
      let(:resource) { DummyResource.new }
      context "and the resource class does not include RDF::Isomorphic" do
        before { class DummyResource; include ActiveTriples::RDFSource; end }
        it "should be false" do
          expect(subject.send(:valid_datatype?, resource)).to be false
        end
      end
      context "and the resource class includes RDF:Isomorphic" do
        before do
          class DummyResource
            include ActiveTriples::RDFSource
            include RDF::Isomorphic
          end
        end
        it "should be false" do
          expect(subject.send(:valid_datatype?, resource)).to be false
        end
      end
      context "and the resource class includes RDF::Isomorphic and aliases :== to :isomorphic_with?" do
        before do
          class DummyResource
            include ActiveTriples::RDFSource
            include RDF::Isomorphic
            alias_method :==, :isomorphic_with?
          end
        end
        it "should be false" do
          expect(subject.send(:valid_datatype?, resource)).to be false
        end
      end
    end
  end
end
