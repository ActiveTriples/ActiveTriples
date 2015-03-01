module ActiveTriples
  ##
  # Persistence strategy for projecting `RDFSource` to `RDF::Repositories`.
  class RepositoryStrategy
    # @!attribute [r] obj
    #   the source to persist with this strategy
    attr_reader :obj

    ##
    # @param obj [RDFSource, RDF::Enumerable] the `RDFSource` (or other
    #   `RDF::Enumerable` to persist with the strategy.
    def initialize(obj)
      @obj = obj
    end

    ##
    # Clear out any old assertions in the repository about this node or statement
    # thus preparing to receive the updated assertions.
    def erase_old_resource
      if obj.rdf_subject.node?
        repository.statements.each do |statement|
          repository.send(:delete_statement, statement) if
            statement.subject == obj.rdf_subject
        end
      else
        repository.delete [obj.rdf_subject, nil, nil]
      end
    end

    ##
    # Deletes the resource from the repository.
    #
    # @return [Boolean] true if the resource was sucessfully destroyed
    def destroy
      obj.clear
      persist!
      @destroyed = true
    end
    alias_method :destroy!, :destroy

    ##
    # Indicates if the Resource has been destroyed.
    #
    # @return [Boolean]
    def destroyed?
      @destroyed ||= false
    end

    ##
    # Persists the object to the repository
    #
    # @return [Boolean]
    def persist!
      erase_old_resource
      repository << obj
      @persisted = true
    end

    ##
    # Indicates if the resource is persisted to the repository
    #
    # @return [Boolean] true if persisted; else false.
    def persisted?
      @persisted ||= false
    end

    ##
    # Repopulates the graph from the repository.
    #
    # @return [Boolean]
    def reload
      obj << repository.query(subject: obj.rdf_subject)
      @persisted = true unless obj.empty?
      true
    end

    ##
    # @return [RDF::Repository] The RDF::Repository that the object will project
    #   itself on when persisting.
    def repository
      @repository ||= set_repository
    end

    private

      ##
      # Finds an appropriate repository from the calling object's configuration.
      # If no repository is configured, builds an ephemeral in-memory
      # repository and 'persists' there.
      #
      # @todo find a way to move this logic out (PersistenceStrategyBuilder?).
      #   so the dependency on Repositories is externalized.
      def set_repository
        repo_sym = obj.class.repository || obj.singleton_class.repository
        if repo_sym.nil?
          RDF::Repository.new
        else
          repo = Repositories.repositories[repo_sym]
          repo || raise(RepositoryNotFoundError, "The class #{obj.class} expects a repository called #{repo_sym}, but none was declared")
        end
      end
  end
end
