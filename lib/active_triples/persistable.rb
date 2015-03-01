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
  end
end
