module ActiveTriples
  ##
  # Bundles the core interfaces used by ActiveTriples persistence strategies
  # to treat a graph as persistable. Specificially:
  #
  #   - RDF::Enumerable
  #   - RDF::Mutable
  #
  # A persistable resource must implement `#graph` as a reference to an
  # `RDF::Graph` or similar.
  module Persistable
    extend ActiveSupport::Concern

    include RDF::Enumerable
    include RDF::Mutable

    ##
    # @see RDF::Enumerable.each
    def each(*args)
      graph.each(*args)
    end

    ##
    # @see RDF::Writable.insert_statement
    def insert_statement(*args)
      graph.send(:insert_statement, *args)
    end

    ##
    # @see RDF::Writable.delete_statement
    def delete_statement(*args)
      graph.send(:delete_statement, *args)
    end

    ##
    # Returns the persistence strategy object that handles this object's
    # persistence
    def persistence_strategy
      @persistence_strategy || set_persistence_strategy(RepositoryStrategy)
    end

    ##
    # Sets a persistence strategy
    #
    # @param klass [Class] A class implementing the persistence strategy
    #   interface
    def set_persistence_strategy(klass)
      @persistence_strategy = klass.new(self)
    end
  end
end
