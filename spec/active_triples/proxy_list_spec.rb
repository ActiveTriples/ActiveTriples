require 'spec_helper'

class ActiveTriples::ProxyList
  def <<(value)
  end
end

class ORE < RDF::Vocabulary('http://www.openarchives.org/ore/1.0/datamodel#'); end
class FOBJ < RDF::Vocabulary('http://fedora.info/definitions/v4/models#'); end

describe ActiveTriples::ProxyList do
  context 'with list items' do
    before do
      proxy = nil
      10.times do |i|
        uri = RDF::URI('http://example.org') / i
        subject << ActiveTriples::Resource.new(uri)

        prev = proxy
        proxy = RDF::Node.new

        graph << RDF::Statement(aggregator, FOBJ.hasMember, uri)
        graph << RDF::Statement(proxy, ORE.proxyIn, aggregator)
        graph << RDF::Statement(proxy, ORE.proxyFor, uri)

        if prev.nil?
          graph << RDF::Statement(aggregator, ORE['first'], proxy)
        else
          graph << RDF::Statement(prev, ORE.next, proxy)
          graph << RDF::Statement(proxy, ORE.prev, prev)
        end
      end

      graph << RDF::Statement(aggregator, ORE.last, proxy)
    end

    let(:aggregator) { ActiveTriples::Resource.new('http://example.org/agg') }
    let(:graph) { RDF::Graph.new }

    it 'outputs the correct graph' do
      require 'pry'
      binding.pry

      expect(subject.dump(:ntriples)).to eq graph
    end
  end
end
