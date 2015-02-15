require 'spec_helper'

class ActiveTriples::ProxyList
  include Enumerable
  extend Forwardable

  def_delegators :elements, :concat

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

  def each
    elements.each { |node| yield(node) }
  end

  def graph
    graph = RDF::Graph.new
    proxy = nil

    elements.each do |element|
      previous_proxy = proxy
      proxy = RDF::Node.new

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

  public

  class UnproxiableObjectError < RuntimeError
  end

  class InvalidAggregatorObjectError < RuntimeError
  end
end

class ORE < RDF::Vocabulary('http://www.openarchives.org/ore/1.0/datamodel#'); end
class FOBJ < RDF::Vocabulary('http://fedora.info/definitions/v4/models#'); end

describe ActiveTriples::ProxyList do
  subject { ActiveTriples::ProxyList.new(aggregator) }
  let(:aggregator) { RDF::URI('http://example.org/agg') }
  let(:uri) { RDF::URI('http://example.org') }

  ##
  # Queries a given predicate with a proxyable value returning the node the
  # proxy stands in for.
  def query_proxy_for(proxy_list, predicate)
    query = RDF::Query.new do
      pattern [proxy_list.aggregator, predicate, :proxy]
      pattern [:proxy, ORE.proxyFor, :value]
    end

    query.execute(proxy_list.graph).map(&:value)
  end

  def query_next_node(proxy_list, current)
    query = RDF::Query.new do
      pattern [:current_proxy, ORE.proxyFor, current]
      pattern [:current_proxy, ORE.next, :next_proxy]
      pattern [:next_proxy, ORE.proxyFor, :next_node]
    end

    query.execute(proxy_list.graph).map(&:next_node)
  end

  RSpec::Matchers.define :have_ore_first_of do |expected|
    match { |actual| query_proxy_for(actual, ORE['first']) == [expected] }
  end

  RSpec::Matchers.define :have_ore_last_of do |expected|
    match { |actual| query_proxy_for(actual, ORE.last) == [expected] }
  end

  RSpec::Matchers.define :have_ore_order_of do |*expected|
    match do |actual|
      current = query_proxy_for(actual, ORE['first']).first
      expected.each do |item|
        return false unless current == item
        current = query_next_node(actual, current)
        current = current.first if current.count == 1
      end
      true
    end
  end

  RSpec::Matchers.define :have_ore_proxy_in do |*expected|
    match do |actual|
      query = RDF::Query.new do
        pattern [:proxy, ORE.proxyIn, actual.aggregator]
        pattern [:proxy, ORE.proxyFor, :member]
      end

      members = query.execute(actual.graph).map(&:member)
      expected.each { |item| return false unless members.include? item }
    end
  end

  it 'will have an aggregator that is an RDF::Resource' do
    expect(subject.aggregator.to_uri).to eq('http://example.org/agg')
  end

  describe '#<<' do
    it 'accepts an RDF::URI' do
      expect { subject << uri }.to change { subject.count }.by(1)
    end

    it 'fails without an RDF::URI (is this correct?)' do
      expect { subject << 'http://google.com' }
        .to raise_error(subject.class::UnproxiableObjectError)
    end

    it 'allows you to push the same RDF::URI' do
      subject << uri
      expect { subject << uri }.to change { subject.count }.by(1)
    end
  end

  describe '#concat' do
    it 'pushes items to list' do
      expect { subject.concat([uri, uri, uri]) }
        .to change { subject.count }.by(3)
    end
  end

  describe '#graph' do
    let(:uri) { RDF::URI('http://example.org') }

    it 'will return a just in time RDF::Graph' do
      subject << uri
      original_graph = subject.graph
      subject << uri
      expect(subject.graph.object_id).to_not eq(original_graph.object_id)
    end

    context 'with one element' do
      before { subject << uri }

      it 'specifies first element' do
        expect(subject).to have_ore_first_of uri
      end

      it 'specifies last element' do
        expect(subject).to have_ore_last_of uri
      end
    end

    context 'with multiple elements' do
      before { subject.concat(uris) }

      let(:uris) do
        uris = []
        10.times { |i| uris << RDF::URI('http://example.org') / i }
        uris
      end

      it 'specifies last element' do
        expect(subject).to have_ore_first_of uris.first
      end

      it 'specifies last element' do
        expect(subject).to have_ore_last_of uris.last
      end

      it 'returns a graph with full order' do
        expect(subject).to have_ore_order_of(*uris)
      end

      it 'returns a graph with correct ORE.proxyIn ' do
        expect(subject).to have_ore_proxy_in(*uris)
      end
    end

    context 'with no elements' do
      it 'will return an empty graph' do
        expect(subject.graph.count).to eq(0)
      end
    end
  end
end
