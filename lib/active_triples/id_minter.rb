module ActiveTriples
  ##
  # Provide a standard interface for minting new IDs and validating
  # the ID is not in use in any known (i.e., registered) repository.
  class IDMinter

    ##
    # Generate a random ID that does not already exist in the
    # triplestore.
    #
    # @param [Class, #read] resource_class: The ID will be minted for
    #    an object of this class, conforming to the configurations
    #    defined in the class' resource model.
    # @param [Function, #read] minter_func: funtion to use to mint
    #    the new ID.  If not specified, the default minter function
    #    will be used to generate an UUID.
    # @param [Hash, #read] options: The options will be passed
    #    through to the minter function, if specified.
    #
    # @return [String] the generated id
    #
    # @raise [Exception] if an available ID is not found in
    #    the maximum allowed tries.
    #
    # @TODO This is inefficient if max_tries is large. Could try
    #    multi-threading. Likely it won't be a problem and should
    #    find an ID within the first few attempts.
    def self.generate_id(for_class, minter_func=nil, options = {}, max_tries=10 )

      raise ArgumentError, 'Argument max_tries must be >= 1 if passed in' if max_tries    <= 0
      raise ArgumentError, 'Argument for_class must be of type class'     unless for_class.class == Class
      raise 'Requires base_uri to be defined in for_class.'               unless for_class.base_uri

      minter_func ||= lambda { |opts| default_minter(opts) }

      found   = true
      test_id = nil
      (1).upto(max_tries) do
          test_id = minter_func.call(options)
          found = for_class.id_persisted?(test_id)
          break unless found
      end
      raise 'Available ID not found.  Exceeded maximum tries.' if found
      test_id
    end

    ##
    # Default minter used by generate_id.
    # @param [Hash] options - not used by this minter
    # @return [String] a uuid
    def self.default_minter( options={} )
      SecureRandom.uuid
    end
  end
end
