module ActiveTriples
  ##
  # @abstract defines the basic interface for persistence of {RDFSource}'s.
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
  end
end
