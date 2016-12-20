module ActiveTriples
  ##
  # Defines the scope of an `RDF::Queryable` to a subgraph defined from a source
  # graph, a starting node, and a list of _bounding nodes_ terms, by a recursive
  # process:
  #
  #  1. All statements in the source graph where the subject of the statement
  #     is the starting node.
  #  2. Add the starting node to the _bounding nodes_ list.
  #  2. For all statements already in the subgraph, include in the subgraph the
  #     Extended Bounded Description for each object node, unless the object is
  #     in the _bounding nodes_ list.
  #
  # The list of _bounding nodes_ begins empty by default. 
  #
  # The subgraph this process yields can be considered as a description of the 
  # starting node.
  #
  # Compare to Concise Bounded Description (https://www.w3.org/Submission/CBD/),
  # the subgraph scope commonly used for SPARQL DESCRIBE queries.
  #
  # @note this implementation requires that the `source_graph` remain unchanged 
  #   while iterating over the description. The safest way to achive this is to 
  #   use an immutable `RDF::Dataset` (e.g. a `Repository#snapshot`).
  class ExtendedBoundedDescription
    include RDF::Enumerable
    include RDF::Queryable
    
    ##
    # @!attribute bounds [r]
    #   @return Array<RDF::Term>
    # @!attribute source_graph [r]
    #   @return RDF::Queryable
    # @!attribute starting_node [r]
    #   @return RDF::Term
    attr_reader  :bounds, :source_graph, :starting_node

    ##
    # By analogy to Concise Bounded Description.
    #
    # @param source_graph  [RDF::Queryable]
    # @param starting_node [RDF::Term]
    # @param bounds        [Array<RDF::Term>] default: []
    def initialize(source_graph, starting_node, bounds = [])
      @source_graph  = source_graph
      @starting_node = starting_node
      @bounds        = bounds
    end
    
    ##
    # @see RDF::Enumerable#each
    def each_statement
      bounds = @bounds.dup

      if block_given?
        statements = source_graph.query(subject: starting_node).each
        statements.each_statement { |st| yield st }
        
        bounds << starting_node
        
        statements.each_object do |object|
          next if object.literal?  || bounds.include?(object)
          ExtendedBoundedDescription
            .new(source_graph, object, bounds).each do |statement|
            yield statement
          end
        end
      end
      enum_statement
    end
    alias_method :each, :each_statement
  end
end
