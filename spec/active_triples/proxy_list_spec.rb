require 'spec_helper'

##
# Acts as a ORE style RDF ordered list.
#
# The implementation is backed by an `elements` array and builds an RDF::Graph
# just-in-time.
class RDF::ProxyList
  include Enumerable
  extend Forwardable

  def_delegators :elements, :empty?

  class << self
    def first_from_graph(aggregator, graph)
      matches = query_proxy_for(aggregator, graph, ORE['first'])
      raise InvalidProxyListGraph if matches.length > 1
      matches.first
    end

    def last_from_graph(aggregator, graph)
      matches = query_proxy_for(aggregator, graph, ORE.last)
      raise InvalidProxyListGraph if matches.length > 1
      matches.first
    end

    def query_next_node(graph, current)
      query = RDF::Query.new do
        pattern [:current_proxy, ORE.proxyFor, current]
        pattern [:current_proxy, ORE.next, :next_proxy]
        pattern [:next_proxy, ORE.proxyFor, :next_node]
      end

      matches = query.execute(graph).map(&:next_node)
      raise InvalidProxyListGraph if matches.length > 1
      matches.first
    end

    private

    ##
    # Queries a given predicate with a proxyable value returning the node the
    # proxy stands in for.
    def query_proxy_for(aggregator, graph, predicate)
      query = RDF::Query.new do
        pattern [aggregator, predicate, :proxy]
        pattern [:proxy, ORE.proxyFor, :value]
      end

      query.execute(graph).map(&:value)
    end
  end

  def initialize(aggregator, graph = nil)
    @aggregator = convert_to_aggregator(aggregator)
    @elements = elements_from_graph(graph)
  end

  attr_reader :elements, :aggregator
  private :elements

  def <<(value)
    resource = convert_to_proxiable_element(value)
    elements << value
  end

  def concat(*args)
    elements.concat(*args)
    self
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

  ##
  # Creates an elements `Array` from a valid ORE Proxy ordered list.
  #
  # The implementation ignores all `ORE.prev` predicates, treating the graph as
  # a singly linked list.
  #
  # @param graph [RDF::Queryable] A graph containing an ORE proxy list.
  # @return [Array<RDF::Resource>] an Array of the resources in the proxy list
  #
  # @raise [InvalidProxyListGraph] if the graph's list is invalid
  def elements_from_graph(graph)
    return [] if graph.nil?

    is_empty = self.class.first_from_graph(aggregator, graph).nil?
    return is_empty ? [] : build_element_list(graph)
  end

  ##
  # @see #elements_from_graph
  def build_element_list(graph)
    list = [self.class.first_from_graph(aggregator, graph)]

    loop do
      next_value = self.class.query_next_node(graph, list.last) || break
      list << next_value
    end
    list
  end

  public

  class UnproxiableObjectError < RuntimeError
  end

  class InvalidAggregatorObjectError < RuntimeError
  end

  class InvalidProxyListGraph < RuntimeError
  end
end

class ORE < RDF::Vocabulary('http://www.openarchives.org/ore/1.0/datamodel#'); end

describe RDF::ProxyList do
  subject { described_class.new(aggregator) }
  let(:aggregator) { RDF::URI('http://example.org/agg') }
  let(:uri) { RDF::URI('http://example.org') }

  RSpec::Matchers.define :have_ore_first_of do |expected|
    match do |actual|
      first = described_class.first_from_graph(actual.aggregator, actual.graph)
      first == expected
    end
  end

  RSpec::Matchers.define :have_ore_last_of do |expected|
    match do |actual|
      last = described_class.last_from_graph(actual.aggregator, actual.graph)
      last == expected
    end
  end

  RSpec::Matchers.define :have_ore_order_of do |*expected|
    match do |actual|
      current = described_class.first_from_graph(actual.aggregator,
                                                 actual.graph)
      expected.each do |item|
        return false unless current == item
        current = described_class.query_next_node(actual.graph, current)
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

  shared_context 'with uri list' do
    let(:uris) do
      uris = []
      10.times { |i| uris << RDF::URI('http://example.org') / i }
      uris
    end
  end

  it 'will have an aggregator that is an RDF::Resource' do
    expect(subject.aggregator.to_uri).to eq('http://example.org/agg')
  end

  describe '.new' do
    subject { described_class.new(aggregator, graph) }

    context 'with empty graph' do
      let(:graph) { RDF::Graph.new }

      it 'initializes with empty list' do
        expect(subject).to be_empty
      end
    end

    context 'with graph without first node' do
      let(:graph) do
        RDF::Graph.new << RDF::Statement(RDF::Node.new, RDF::DC.title, 'moomin')
      end

      it 'initializes with empty list' do
        expect(subject).to be_empty
      end
    end

    context 'with graph with list items' do
      include_context 'with uri list'

      let(:graph) { described_class.new(aggregator).concat(uris).graph }

      it do
        expect(subject).to have_ore_order_of(*uris)
      end
    end
  end

  describe '.first_from_graph' do
    it 'returns first item'

    it 'raises error when more than one first is present'

    it 'returns nil for empty list'
  end

  describe '.last_from_graph' do
    it 'returns first item'

    it 'raises error when more than one last is present'

    it 'returns ?? for empty list'
  end

  describe '.query_next_node' do
    it 'returns first item'

    it 'raises error when more than one next is present'

    it 'raises nil when there is no next item'
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

    it 'returns self' do
      expect(subject.concat([uri, uri, uri])).to eq subject
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
      include_context 'with uri list'

      before { subject.concat(uris) }

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
