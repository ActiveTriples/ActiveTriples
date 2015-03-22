module ActiveTriples
  ##
  # @abstract defines the basic interface for persistence of {RDFSource}'s.
  #
  # A `PersistenceStrategy` has an underlying object (`obj`) which should 
  # be an `RDFSource` or equivalent. Strategies can be injected into `RDFSource`
  # instances at runtime to change the target datastore, repository, or object 
  # the instance syncs its graph with on save and reload operations.
  #
  # @example Changing a PersistenceStrategy at runtime
  #    source = ActiveTriples::Resource.new
  #    source.persistence_strategy # => #<ActiveTriples::RepositoryStrategy:...>
  #   
  #    source.set_persistence_strategy(MyStrategy)
  #    source.persistence_strategy # => #<ActiveTriples::MyStrategy:...>
  #
  module PersistenceStrategy
    ##
    # Deletes the resource from the repository.
    #
    # @yield prior to persisting, yields to allow a block that performs
    #   deletions in the persisted graph(s).
    # @return [Boolean] true if the resource was sucessfully destroyed
    def destroy(&block)
      obj.clear
      yield if block_given?
      persist!
      @destroyed = true
    end
    alias_method :destroy!, :destroy

    ##
    # Indicates if the Resource has been destroyed.
    #
    # @return [true, false]
    def destroyed?
      @destroyed ||= false
    end

    ##
    # Indicates if the resource is persisted to the repository
    #
    # @return [Boolean] true if persisted; else false.
    def persisted?
      @persisted ||= false
    end

    ##
    # @abstract save the object according to the strategy and set the 
    #   @persisted flag to `true`
    #
    # @see #persisted?
    #
    # @return [true] true if the save did not error
    def persist!
      raise NotImplementedError, 'Abstract method #persist! is unimplemented'
    end

    ##
    # @abstract Clear out any old assertions in the repository about this node 
    # or statement thus preparing to receive the updated assertions.
    #
    # @return [Boolean]
    def erase_old_resource
      raise NotImplementedError, 
            'Abstract method #erase_old_resource is unimplemented'
    end

    ##
    # @abstract Repopulate the in-memory graph from the persisted graph
    #
    # @return [Boolean]
    def reload
      raise NotImplementedError, 'Abstract method #reload is unimplemented'
    end
  end
end
