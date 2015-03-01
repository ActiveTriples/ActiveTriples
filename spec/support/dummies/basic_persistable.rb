class BasicPersistable
  include ActiveTriples::Persistable

  attr_reader :graph

  def initialize
    @graph = RDF::Graph.new
  end
end
