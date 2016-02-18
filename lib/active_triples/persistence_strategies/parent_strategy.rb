# frozen_string_literal: true
module ActiveTriples
  ##
  # Persistence strategy for projecting `RDFSource`s onto the graph of an owning
  # parent source. This allows individual resources to be treated as within the
  # scope of another `RDFSource`.
  class ParentStrategy
    include PersistenceStrategy

    # @!attribute [r] source
    #   the source to persist with this strategy
    # @!attribute [r] parent
    #   the target parent source for persistence
    attr_reader :source, :parent

    ##
    # @param source [RDFSource, RDF::Enumerable] the `RDFSource` (or other
    #   `RDF::Enumerable` to persist with the strategy.
    def initialize(source)
      @source = source
    end

    ##
    # Resources using this strategy are persisted only if their parent is also 
    # persisted.
    #
    # @see PersistenceStrategy#persisted?
    def persisted?
      super && parent.persisted?
    end

    ##
    # Destroys the resource by removing it graph and references from the 
    # parent.
    #
    # @see PersistenceStrategy#destroy
    def destroy
      final_parent.delete(source.statements)

      parent.statements.each do |statement|
        parent.delete_statement(statement) if
          statement.subject == source.rdf_subject || 
          statement.object == source.rdf_subject
      end

      super { source.clear }
    end

    ##
    # @abstract Clear out any old assertions in the datastore / repository 
    # about this node  or statement thus preparing to receive the updated 
    # assertions.
    def erase_old_resource
      final_parent.statements.each do |statement|
        final_parent.send(:delete_statement, statement) if
          statement.subject == source.rdf_subject
      end
    end

    ##
    # @return [Enumerator<RDFSource>]
    def ancestors
      Ancestors.new(source).to_enum
    end

    ##
    # @return [#persist!] the last parent in a chain from `parent` (e.g.
    #   the parent's parent's parent). This is the RDF::Mutable that the
    #   resource will project itself on when persisting.
    def final_parent
      ancestors.to_a.last
    end

    ##
    # Sets the target "parent" source for persistence operations.
    #
    # @param parent [RDFSource] source with a persistence strategy,
    #   must be mutable.
    def parent=(parent)
      raise UnmutableParentError unless parent.is_a? RDF::Mutable
      raise UnmutableParentError unless parent.mutable?
      @parent = parent
    end

    ##
    # Persists the resource to the final parent.
    #
    # @return [true] true if the save did not error
    def persist!
      erase_old_resource
      final_parent << source
      @persisted = true
    end

    ##
    # Repopulates the graph from parent.
    #
    # @return [Boolean]
    def reload
      source << final_parent.query(subject: source.rdf_subject)
      @persisted = true unless source.empty?
      true
    end

    ##
    # An enumerable over the ancestors of an resource
    class Ancestors
      include Enumerable

      # @!attribute source
      #   @return [RDFSource]
      attr_reader :source

      ##
      # @param source [RDFSource]
      def initialize(source)
        @source = source
      end
      
      ##
      # @yield [RDFSource] gives each ancestor to the block
      # @return [Enumerator<RDFSource>]
      #
      # @raise [NilParentError] if `source` does not persist to a parent
      def each
        raise NilParentError if 
          !source.persistence_strategy.respond_to?(:parent) || 
          source.persistence_strategy.parent.nil?
        
        current = source.persistence_strategy.parent
        
        if block_given?
          loop do
            yield current
            
            break unless (current.persistence_strategy.respond_to?(:parent) && 
                          current.persistence_strategy.parent)
            break if current.persistence_strategy.parent == current

            current = current.persistence_strategy.parent
          end
        end
        to_enum
      end
    end
    
    class NilParentError < RuntimeError; end
    class UnmutableParentError < ArgumentError; end
  end
end
