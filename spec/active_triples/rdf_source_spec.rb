require 'spec_helper'
require 'rdf/spec/enumerable'
require 'rdf/spec/queryable'
require 'rdf/spec/countable'
require 'rdf/spec/mutable'

describe ActiveTriples::RDFSource do
  before { @enumerable = subject }

  subject { Class.new { include ActiveTriples::RDFSource }.new }

  describe 'RDF interface' do
    it { is_expected.to be_enumerable }
    it { is_expected.to be_queryable }
    it { is_expected.to be_countable }
    it { is_expected.to be_a_value }
    # it { is_expected.to be_a_term }
    # it { is_expected.to be_a_resource }

    let(:enumerable) { Class.new { include ActiveTriples::RDFSource }.new }
    it_behaves_like 'an RDF::Enumerable'

    let(:queryable) { enumerable }
    it_behaves_like 'an RDF::Queryable'

    let(:countable) { enumerable }
    it_behaves_like 'an RDF::Countable'

    let(:mutable) { enumerable }
    it_behaves_like 'an RDF::Mutable'
  end
end
