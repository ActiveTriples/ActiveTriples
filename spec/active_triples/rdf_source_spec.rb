require 'spec_helper'
require 'rdf/spec/enumerable'
require 'rdf/spec/queryable'
require 'rdf/spec/countable'
require 'rdf/spec/mutable'

describe ActiveTriples::RDFSource do
  it_behaves_like 'an ActiveModel' do
    let(:am_lint_class) do
      class AMLintClass
        include ActiveTriples::RDFSource
      end
    end

    after { Object.send(:remove_const, :AMLintClass) if defined?(AMLintClass) }
  end

  before { @enumerable = subject }
  let(:source_class) { Class.new { include ActiveTriples::RDFSource } }
  let(:uri) { RDF::URI('http://example.org/moomin') }

  subject { source_class.new }

  describe 'RDF interface' do
    it { is_expected.to be_enumerable }
    it { is_expected.to be_queryable }
    it { is_expected.to be_countable }
    it { is_expected.to be_a_value }
    # it { is_expected.to be_a_term }
    # it { is_expected.to be_a_resource }

    let(:enumerable) { source_class.new }
    it_behaves_like 'an RDF::Enumerable'

    let(:queryable) { enumerable }
    # it_behaves_like 'an RDF::Queryable'

    let(:countable) { enumerable }
    it_behaves_like 'an RDF::Countable'

    let(:mutable) { enumerable }
    it_behaves_like 'an RDF::Mutable'

    describe 'Term behavior' do
      it { is_expected.to be_term }

      it 'is termified when added to an Statement' do
        expect(RDF::Statement(subject, nil, nil).subject).to eq subject
      end

      context 'as a node' do
        describe '#uri?' do
          it { is_expected.not_to be_uri }
        end

        describe '#node?' do
          it { is_expected.to be_node }
        end

        describe '#to_term' do
          its(:to_term) { is_expected.to be_node }
        end

        describe '#to_base' do
          its(:to_base) { is_expected.to be_a String }
          its(:to_base) { is_expected.to eq subject.to_term.to_base }
        end
      end

      context 'as a uri' do
        subject { source_class.new(uri) }

        describe '#uri?' do
          it { is_expected.to be_uri }
        end

        describe '#node?' do
          it { is_expected.not_to be_node }
        end

        describe '#to_term' do
          its(:to_term) { is_expected.to be_uri }
        end

        describe '#to_uri' do
          its(:to_uri) { is_expected.to be_uri }
        end

        describe '#to_base' do
          its(:to_base) { is_expected.to be_a String }
          its(:to_base) { is_expected.to eq subject.to_term.to_base }
        end
      end
    end
  end

  describe '#==' do
    shared_examples 'Term equality' do
      it 'equals itself' do
        expect(subject).to eq subject
      end

      it 'equals its own Term' do
        expect(subject).to eq subject.to_term
      end

      it 'is symmetric' do
        expect(subject.to_term).to eq subject
      end

      it 'does not equal another term' do
        expect(subject).not_to eq RDF::Node.new
      end
    end

    include_examples 'Term equality'

    context 'with a URI' do
      include_examples 'Term equality' do
        subject { source_class.new(uri) }
      end
    end
  end

  describe '#fetch' do
    it 'raises an error when it is a node' do
      expect { subject.fetch }
        .to raise_error "#{subject} is a blank node; Cannot fetch a resource " \
                        'without a URI'
    end

    context 'with a valid URI' do
      subject { source_class.new(uri) }

      context 'with a bad link' do
        before { stub_request(:get, uri).to_return(:status => 404) }

        it 'raises an error if no block is given' do
          expect { subject.fetch }.to raise_error IOError
        end

        it 'yields self to block' do
          expect { |block| subject.fetch(&block) }.to yield_with_args(subject)
        end
      end

      context 'with a working link' do
        before do
          stub_request(:get, uri).to_return(:status => 200,
                                            :body => graph.dump(:ttl))
        end

        let(:graph) { RDF::Graph.new << statement }

        let(:statement) do
          RDF::Statement(subject, RDF::Vocab::DC.title, 'moomin')
        end

        it 'loads retrieved graph into its own' do
          expect { subject.fetch }
            .to change { subject.statements.to_a }
                 .from(a_collection_containing_exactly())
                 .to(a_collection_containing_exactly(statement))
        end

        it 'merges retrieved graph into its own' do
          existing = RDF::Statement(subject, RDF::Vocab::DC.creator, 'Tove')
          subject << existing

          expect { subject.fetch }
            .to change { subject.statements.to_a }
                 .from(a_collection_containing_exactly(existing))
                 .to(a_collection_containing_exactly(statement, existing))
        end
      end
    end
  end

  describe '#graph_name' do
    it 'returns nil' do
      expect(subject.graph_name).to be_nil
    end
  end

  describe '#humanize' do
    it 'gives the "" for a node' do
      expect(subject.humanize).to eq ''
    end

    it 'gives a URI string for a URI resource' do
      allow(subject).to receive(:rdf_subject).and_return(uri)
      expect(subject.humanize).to eq uri.to_s
    end
  end

  describe '#rdf_subject' do
    its(:rdf_subject) { is_expected.to be_a_node }

    context 'with a URI' do
      subject { source_class.new(uri) }

      its(:rdf_subject) { is_expected.to be_a_uri }
      its(:rdf_subject) { is_expected.to eq uri }
    end
  end

  describe '#get_values' do
    before { statements.each { |statement| subject << statement } }

    let(:predicate) { RDF::Vocab::DC.creator } 
    let(:property_name) { :creator }
    let(:values) { ['Tove Jansson', subject] }

    let(:source_class) do
      class SourceWithCreator
        include ActiveTriples::RDFSource

        property :creator, predicate: RDF::Vocab::DC.creator 
      end
      SourceWithCreator
    end

    let(:statements) do
      values.map { |value| RDF::Statement(subject, predicate, value) }
    end

    it 'gets values for a property name' do
      expect(subject.get_values(property_name))
        .to be_a_relation_containing(*values)
    end

    it 'gets values for a predicate' do
      expect(subject.get_values(predicate))
        .to be_a_relation_containing(*values)
    end

    it 'gets values with two args' do
      val = 'momma'
      other_uri = uri / val
      subject << RDF::Statement(other_uri, predicate, val)

      expect(subject.get_values(other_uri, predicate))
        .to be_a_relation_containing(val)
    end
  end

  describe '#set_value' do
    it 'raises argument error when given too many arguments' do
      expect { subject.set_value(double, double, double, double) }
        .to raise_error ArgumentError
    end

    it 'raises an error when given an unregistered property name' do
      expect { subject.set_value(:not_a_property, 'moomin') }.to raise_error
    end

    shared_examples 'setting values' do
      after do
        Object.send(:remove_const, 'SourceWithCreator') if 
          defined? SourceWithCreator
      end

      let(:source_class) do
        class SourceWithCreator
          include ActiveTriples::RDFSource
          property :creator, predicate: RDF::Vocab::DC.creator 
        end
        SourceWithCreator
      end

      let(:predicate) { RDF::Vocab::DC.creator } 
      let(:property_name) { :creator }
      let(:statements) do
        Array.wrap(value).map { |val| RDF::Statement(subject, predicate, val) }
      end

      it 'sets a value' do
        expect { subject.set_value(predicate, value) }
          .to change { subject.statements }
               .to(a_collection_containing_exactly(*statements))
      end

      it 'sets a value with a property name' do
        expect { subject.set_value(property_name, value) }
          .to change { subject.statements }
               .to(a_collection_containing_exactly(*statements))
      end

      it 'overwrites existing values' do
        old_vals = ['old value', 
                    RDF::Node.new, 
                    RDF::Vocab::DC.type, 
                    RDF::URI('----')]

        subject.set_value(predicate, old_vals)

        expect { subject.set_value(predicate, value) }
          .to change { subject.statements }
               .to(a_collection_containing_exactly(*statements))
      end

      it 'returns the set values in a Relation' do
        expect(subject.set_value(predicate, value))
          .to be_a_relation_containing(*Array.wrap(value))
      end
    end
    
    context 'with string literal' do
      include_examples 'setting values' do
        let(:value) { 'moomin' }
      end
    end

    context 'with multiple values' do
      include_examples 'setting values' do
        let(:value) { ['moominpapa', 'moominmama'] }
      end
    end

    context 'with typed literal' do
      include_examples 'setting values' do
        let(:value) { Date.today }
      end
    end

    context 'with RDF Term' do
      include_examples 'setting values' do
        let(:value) { RDF::Node.new }
      end
    end

    context 'with RDFSource node' do
      include_examples 'setting values' do
        let(:value) { source_class.new }
      end
    end

    context 'with RDFSource uri' do
      include_examples 'setting values' do
        let(:value) { source_class.new(uri) }
      end
    end

    context 'with self' do
      include_examples 'setting values' do
        let(:value) { subject }
      end
    end

    context 'with mixed values' do
      include_examples 'setting values' do
        let(:value) do
          ['moomin', 
           Date.today, 
           RDF::Node.new, 
           source_class.new, 
           source_class.new(uri), 
           subject]
        end
      end
    end
  end

  describe '#get_value' do
    context 'with no matching property' do
      it 'returns a Relation' do
        expect(subject.get_values(:not_a_predicate))
          .to be_a ActiveTriples::Relation
      end

      it 'is empty' do
        expect(subject.get_values(:not_a_predicate))
          .to be_empty
      end
    end

    context 'with an empty predicate' do
      let(:predicate) { RDF::URI('http://example.org/empty') }

      it 'returns a Relation' do
        expect(subject.get_values(predicate)).to be_a ActiveTriples::Relation
      end

      it 'is empty' do
        expect(subject.get_values(predicate)).to be_empty
      end
    end

    it 'gets a value'
  end

  describe 'validation' do
    let(:invalid_statement) do
      RDF::Statement.from([RDF::Literal.new('blah'),
                           RDF::Literal.new('blah'),
                           RDF::Literal.new('blah')])
    end

    it { is_expected.to be_valid }

    it 'is valid with valid statements' do
      subject.insert(*RDF::Spec.quads)
      expect(subject).to be_valid
    end

    it 'is valid with valid URI' do
      source_class.new(uri)
      expect(subject).to be_valid
    end

    context 'with invalid URI' do
      before do
        allow(subject).to receive(:rdf_subject).and_return(RDF::URI('----'))
      end

      it { is_expected.not_to be_valid }
    end

    context 'with invalid statement' do
      before { subject << invalid_statement }

      it 'is invalid' do
        expect(subject).to be_invalid
      end

      it 'adds error message' do
        expect { subject.valid? }
          .to change { subject.errors.messages }
               .from({})
               .to({ base: ["The underlying graph must be valid"] })
      end
    end

    context 'with ActiveModel validation' do
      let(:source_class) do
        class Validation
          include ActiveTriples::RDFSource

          validates_presence_of :title

          property :title, predicate: RDF::Vocab::DC.title
        end

        Validation
      end

      after { Object.send(:remove_const, :Validation) }

      context 'with invalid property' do
        it { is_expected.to be_invalid }

        it 'has errors' do
          expect { subject.valid? }
            .to change { subject.errors.messages }
                 .from({})
                 .to({ title: ["can't be blank"] })
        end
      end

      context 'when properties are valid' do
        before { subject.title = 'moomin' }

        it { is_expected.to be_valid }

        context 'and has invaild statements' do
          before { subject << invalid_statement }

          it { is_expected.to be_invalid }

          it 'has errors' do
            expect { subject.valid? }
              .to change { subject.errors.messages }
                   .from({})
                   .to(include({ base: ["The underlying graph must be valid"] }))
          end
        end
      end
    end
  end

  describe ".apply_schema" do
    let(:dummy_source) { Class.new { include ActiveTriples::RDFSource } }

    before do
      class MyDataModel < ActiveTriples::Schema
        property :test_title, :predicate => RDF::Vocab::DC.title
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
