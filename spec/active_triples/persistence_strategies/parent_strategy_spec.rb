require 'spec_helper'

describe ActiveTriples::ParentStrategy do
  subject { described_class.new(rdf_source) }
  let(:rdf_source) { BasicPersistable.new }

  shared_context 'with a parent' do
    before do
      subject.parent = parent
    end

    let(:parent) { BasicPersistable.new }
  end

  context 'with a parent' do
    include_context 'with a parent'
    it_behaves_like 'a persistence strategy'

    describe '#persisted?' do
      context 'before persist!' do
        it 'returns false' do
          expect(subject).not_to be_persisted
        end
      end

      context 'after persist!' do
        context "when the parent is not persisted" do
          before { subject.persist! }
          it { is_expected.not_to be_persisted }
        end

        context "when the parent is persisted" do
          before do
            allow(parent).to receive(:persisted?).and_return(true)
            subject.persist!
          end
          it { is_expected.to be_persisted }
        end
      end
    end
  end

  describe '#final_parent' do
    it 'raises an error with no parent' do
      expect { subject.final_parent }.to raise_error described_class::NilParentError
    end

    context 'with single parent' do
      include_context 'with a parent'

      it 'gives parent' do
        expect(subject.final_parent).to eq subject.parent
      end
    end

    context 'with parent chain' do
      include_context 'with a parent'
      let(:last) { double('last') }

      it 'gives last parent terminating when no futher parents given' do
        allow(parent).to receive(:parent).and_return(last)
        expect(subject.final_parent).to eq last
      end

      it 'gives last parent terminating parent is nil' do
        allow(parent).to receive(:parent).and_return(last)
        allow(last).to receive(:parentt).and_return(nil)
        expect(subject.final_parent).to eq last
      end

      it 'gives last parent terminating parent is same as current' do
        allow(parent).to receive(:parent).and_return(last)
        allow(last).to receive(:parentt).and_return(last)
        expect(subject.final_parent).to eq last
      end
    end
  end

  describe '#parent' do
    it { is_expected.to have_attributes(:parent => nil) }

    it 'requires its parent to be RDF::Mutable' do
      expect { subject.parent = Object.new }
        .to raise_error described_class::UnmutableParentError
    end

    it 'requires its parent to be #mutable?' do
      immutable = double
      allow(immutable).to receive(:mutable?).and_return(false)
      expect { subject.parent = immutable }
        .to raise_error described_class::UnmutableParentError
    end

    context 'with a parent' do
      include_context 'with a parent'
      it { is_expected.to have_attributes(:parent => parent) }
    end
  end

  describe '#persist!' do
    it 'raises an error with no parent' do
      expect { subject.persist! }.to raise_error described_class::NilParentError
    end

    context 'with parent' do
      include_context 'with a parent'

      it 'writes to #final_parent graph' do
        rdf_source << RDF::Statement.new(RDF::Node.new, RDF::DC.title, 'moomin')
        subject.persist!
        expect(subject.final_parent.statements)
          .to contain_exactly *rdf_source.statements
      end
    end
  end
end
