module ActiveTriples
  ##
  # A buffered trasaction for use with `ActiveTriples::ParentStrategy`.
  #
  # Reads are projected onto a specialized "Extended Bounded Description" 
  # subgraph. Compare to Concise Bounded Description 
  # (https://www.w3.org/Submission/CBD/), the common subgraph scope used for 
  # SPARQL DESCRIBE queries.
  #
  # If an `ActiveTriples::RDFSource` instance is passed as the underlying 
  # repository, this transaction will try to find an existing 
  # `BufferedTransaction` to use as the basis for a snapshot. When the 
  # transaction is executed, the inserts and deletes are replayed against the
  # `RDFSource`.
  #
  # If a `RDF::Transaction::TransactionError` is raised on commit, this 
  # transaction optimistically attempts to replay the changes.
  class BufferedTransaction < RDF::Repository::Implementation::SerializedTransaction
    # @!attribute snapshot [r]
    #   @return RDF::Dataset
    # @!attribute subject [r]
    #   @return RDF::Term
    # @!attribute ancestors [r]
    #   @return Array<RDF::Term>
    attr_reader :snapshot, :subject, :ancestors
    
    def initialize(repository,
                   ancestors:  [],
                   subject:    nil, 
                   graph_name: nil, 
                   mutable:    false, 
                   **options,
                   &block)
      @subject   = subject
      @ancestors = ancestors

      if repository.is_a?(RDFSource)
        if repository.persistence_strategy.graph.is_a?(BufferedTransaction)
          super
          @snapshot = repository.persistence_strategy.graph.snapshot
          return
        else
          repository = repository.persistence_strategy.graph.data
        end
      end

      return super
    end

    ##
    # Provides :repeatable_read isolation (???)
    #
    # @see RDF::Transaction#isolation_level
    def isolation_level
      :repeatable_read
    end

    ##
    # @return [BufferedTransaction] self
    def data
      self
    end

    ##
    # @see RDF::Mutable#supports
    def supports?(feature)
      return true if feature.to_sym == :snapshots
    end

    ##
    # Adds statement to the `inserts` collection of the buffered changeset and
    # updates the snapshot.
    #
    # @see RDF::Mutable#insert_statement
    def insert_statement(statement)
      @changes.insert(statement)
      @changes.deletes.delete(statement)
      super
    end

    ##
    # Adds statement to the `deletes` collection of the buffered changeset and
    # updates the snapshot.
    #
    # @see RDF::Transaction#delete_statement
    def delete_statement(statement)
      @changes.delete(statement)
      @changes.inserts.delete(statement)
      super
    end

    ##
    # Executes optimistically. If errors are encountered, we replay the buffer 
    # on the latest version.
    # 
    # If the `repository` is a transaction, we immediately replay the buffer 
    # onto it.
    #
    # @see RDF::Transaction#execute
    def execute
      raise TransactionError, 'Cannot execute a rolled back transaction. ' \
                              'Open a new one instead.' if @rolledback
      return if changes.empty?
      return super unless repository.is_a?(ActiveTriples::RDFSource)

      repository.insert(changes.inserts)
      repository.delete(changes.deletes)
    rescue RDF::Transaction::TransactionError => err
      raise err if @rolledback

      # replay changest on the current version of the repository
      repository.delete(*changes.deletes)
      repository.insert(*changes.inserts)
    end

    private
    
    def read_target
      return super unless subject
      extended_bounded_description(super, subject, ancestors.dup)
    end

    ##
    # By analogy to Concise Bounded Description.
    #
    # Include in the subgraph:
    #  1. All statements in the source graph where the subject of the statement 
    #     is the starting node.
    #  2. Recursively, for all statements already in the subgraph, include in 
    #     the subgraph the Extended Bounded Description for each object node, 
    #     unless the object is in the ancestor's list.
    #
    # @param target    [RDF::Queryable]
    # @param subject   [RDF::Term]
    # @param ancestors [Array<RDF::Term>]
    #
    # @return [RDF::Enumerable, RDF::Queryable]
    def extended_bounded_description(target, subject, ancestors)
      statements = RDF::Repository.new << target.query(subject: subject)

      ancestors ||= []
      ancestors << subject

      statements.each_object do |object|
        next if object.literal?  || ancestors.include?(object)

        statements << extended_bounded_description(target, object, ancestors)
        ancestors  << object
      end

      statements
    end
  end
end
