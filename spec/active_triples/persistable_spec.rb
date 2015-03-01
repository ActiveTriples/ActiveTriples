require 'spec_helper'

describe ActiveTriples::Persistable do
  subject { klass.new }

  let(:klass) do
    klass = Class.new
    klass.include ActiveTriples::Persistable
    klass
  end
  let(:statement) { RDF::Statement(RDF::Node.new, RDF::DC.title, 'Moomin') }

  it 'raises an error with no #graph implementation' do
    expect { subject << statement }.to raise_error(NameError, /graph/)
  end

  context 'with graph implementation' do
    before do
      graph = RDF::Graph.new
      allow(subject).to receive(:graph).and_return(graph)
    end

    it 'mirrors writes to graph' do
      subject << statement
      expect(subject.graph).to contain_exactly statement
    end
  end
end
