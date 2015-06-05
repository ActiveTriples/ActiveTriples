require 'spec_helper'
require 'rdf/spec/enumerable'
require 'rdf/spec/queryable'
require 'rdf/spec/countable'
require 'rdf/spec/mutable'

describe ActiveTriples::RDFSource do
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
    it_behaves_like 'an RDF::Queryable'

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

  describe '#id' do
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

  describe '#set_value' do
    it 'raises argument error when given too many arguments' do
      expect { subject.set_value(double, double, double, double) }
        .to raise_error ArgumentError
    end

    it 'sets a value'
  end

  describe "inheritance" do
    before do
      class PrincipalResource
        include ActiveTriples::RDFSource

        configure type: RDF::FOAF.Agent
        property :name, predicate: RDF::FOAF.name
      end

      class UserSource < PrincipalResource
        configure type: RDF::FOAF.Person
      end

      class DummySource
        include ActiveTriples::RDFSource

        property :creator, predicate: RDF::DC.creator
      end
    end

    after do
      Object.send(:remove_const, :PrincipalResource)
      Object.send(:remove_const, :UserSource)
      Object.send(:remove_const, :DummySource)
    end

    let(:dummy) { DummySource.new }
    let(:bob) { UserSource.new.tap {|u| u.name = "bob"} }
    let(:sally) { UserSource.new.tap {|u| u.name = "sally"} }

    it "should replace values" do
      dummy.creator = bob
      expect(dummy.creator).to eq [bob]
      dummy.creator = sally
      expect(dummy.creator).to eq [sally]
    end
  end

  describe 'validation' do
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
      before { subject << RDF::Statement.from([nil, nil, nil]) }

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
  end
end
