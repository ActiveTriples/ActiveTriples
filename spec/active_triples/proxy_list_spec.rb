require 'spec_helper'

class ActiveTriples::ProxyList
  class UnproxiableObjectError < RuntimeError
  end

  class InvalidAggregatorObjectError < RuntimeError
  end

  def initialize(aggregator)
    @aggregator = convert_to_aggregator(aggregator)
    @elements = []
  end
  attr_reader :elements, :aggregator
  private :elements

  def <<(value)
    resource = convert_to_proxiable_element(value)
    elements << value
  end

  include Enumerable

  def each
    elements.each { |node| yield(node) }
  end

  def graph
    graph = RDF::Graph.new
    proxy = nil

    elements.each do |element|
      previous_proxy = proxy
      proxy = RDF::Node.new

      graph << RDF::Statement(aggregator, FOBJ.hasMember, element)
      graph << RDF::Statement(proxy, ORE.proxyIn, aggregator)
      graph << RDF::Statement(proxy, ORE.proxyFor, element)

      if previous_proxy.nil?
        graph << RDF::Statement(aggregator, ORE['first'], proxy)
      else
        graph << RDF::Statement(previous_proxy, ORE.next, proxy)
        graph << RDF::Statement(proxy, ORE.prev, previous_proxy)
      end
    end

    graph << RDF::Statement(aggregator, ORE.last, proxy) if proxy
    graph
  end

  private

  def convert_to_aggregator(value)
    case value
    when String
      RDF::URI(value)
    when RDF::URI, RDF::Node, RDF::Resource
      value
    else
      fail InvalidAggregatorObjectError, "Unable to convert #{value.inspect} to an aggregator"
    end
  end

  def convert_to_proxiable_element(value)
    case value
    when RDF::URI
      value
    else
      fail UnproxiableObjectError, "Unable to convert #{value} to a ProxyList element"
    end
  end
end

class ORE < RDF::Vocabulary('http://www.openarchives.org/ore/1.0/datamodel#'); end
class FOBJ < RDF::Vocabulary('http://fedora.info/definitions/v4/models#'); end

describe ActiveTriples::ProxyList do
  subject { ActiveTriples::ProxyList.new(aggregator) }
  let(:aggregator) { RDF::URI('http://example.org/agg') }

  context 'with list items (integration test)' do

    before do
      proxy = nil
      10.times do |i|
        uri = RDF::URI('http://example.org') / i
        subject << uri

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

    let(:graph) { RDF::Graph.new }

    it 'outputs the correct graph' do
      # expect(subject.dump(:ntriples)).to eq graph.dump(:ntriples)
    end
  end

  it 'will have an aggregator that is an RDF::Resource' do
    expect(subject.aggregator.to_uri).to eq('http://example.org/agg')
  end

  context '#<<' do
    let(:uri) { RDF::URI('http://example.org') }

    it 'will accept an RDF::URI' do
      expect { subject << uri }.to change { subject.count }.by(1)
    end

    it 'will fail without an RDF::URI (is this correct?)' do
      expect { subject << 'http://google.com' }.to raise_error(subject.class::UnproxiableObjectError)
    end

    it 'will allow you to push the same RDF::URI' do
      subject << uri
      expect { subject << uri }.to change { subject.count }.by(1)
    end
  end

  context '#graph' do
    let(:uri) { RDF::URI('http://example.org') }

    it 'will return a just in time RDF::Graph' do
      subject << uri
      original_graph = subject.graph
      subject << uri
      expect(subject.graph.object_id).to_not eq(original_graph.object_id)
    end

    context 'with one element' do
      it 'will return a graph with 5 statements' do
        subject << uri
        expect(subject.graph.count).to eq(5)
      end
    end

    context 'with no elements' do
      it 'will return an empty graph' do
        expect(subject.graph.count).to eq(0)
      end
    end
  end
end
