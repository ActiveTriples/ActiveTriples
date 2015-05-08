module ActiveTriples
  ##
  # Persistence strategy for projecting `RDFSource`s onto the graph of an owning
  # parent source. This allows individual resources to be treated as within the
  # scope of another `RDFSource`.
  class ParentStrategy
    include PersistenceStrategy

    # @!attribute [r] obj
    #   the source to persist with this strategy
    # @!attribute [r] parent
    #   the target parent source for persistence
    attr_reader :obj, :parent

    ##
    # @param obj [RDFSource, RDF::Enumerable] the `RDFSource` (or other
    #   `RDF::Enumerable` to persist with the strategy.
    def initialize(obj)
      @obj = obj
    end

    def destroy
      super { parent.destroy_child(obj) }
    end

    # Clear out any old assertions in the repository about this node or statement
    # thus preparing to receive the updated assertions.
    def erase_old_resource
      if obj.rdf_subject.node?
        final_parent.statements.each do |statement|
          final_parent.send(:delete_statement, statement) if
            statement.subject == obj.rdf_subject
        end
      else
        final_parent.delete [obj.rdf_subject, nil, nil]
      end
    end

    ##
    # @return [#persist!] the last parent in a chain from `parent` (e.g.
    #   the parent's parent's parent). This is the RDF::Mutable that the
    #   object will project itself on when persisting.
    def final_parent
      raise NilParentError if parent.nil?
      @final_parent ||= begin
        current = self.parent
        while current && current.respond_to?(:parent) && current.parent
          break if current.parent == current
          current = current.parent
        end
        current
      end
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
    # Persists the object to the final parent.
    def persist!
      erase_old_resource
      final_parent << obj
      @persisted = true
    end

    ##
    # Repopulates the graph from parent.
    #
    # @return [Boolean]
    def reload
      obj << final_parent.query(subject: obj.rdf_subject)
      @persisted = true unless obj.empty?
      true
    end

    class NilParentError < RuntimeError; end
    class UnmutableParentError < ArgumentError; end
  end
end
