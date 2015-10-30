module ActiveTriples
  ##
  # Defines module methods for registering an RDF::Repository for
  # persistence of Resources.
  #
  # This allows any triplestore (or other storage platform) with an
  # RDF::Repository implementation to be used for persistence of
  # resources that will be shared between ActiveFedora::Base objects.
  #
  #    ActiveTriples::Repositories.add_repository :blah, RDF::Repository.new
  #
  # Multiple repositories can be registered to keep different kinds of
  # resources seperate. This is configurable on subclasses of Resource
  # at the class level.
  #
  # @see Configurable
  module Repositories

    ##
    # @param name [Symbol] 
    # @param repo [RDF::Repository] 
    #
    # @return [RDF::Repository]
    # @raise [ArgumentError] if a non-repository is passed
    def add_repository(name, repo)
      raise ArgumentError, "Repositories must be an RDF::Repository" unless 
        repo.kind_of? RDF::Repository
      repositories[name] = repo
    end
    module_function :add_repository

    def clear_repositories!
      @repositories = {}
    end
    module_function :clear_repositories!

    def repositories
      @repositories ||= {}
    end
    module_function :repositories

    ##
    # Check for the specified rdf_subject in the specified repository
    # defaulting to search all registered repositories.
    # @param [String] rdf_subject
    # @param [Symbol] repository name
    def has_subject?(rdf_subject,repo_name=nil)
      search_repositories = [repositories[repo_name]] if repo_name
      search_repositories ||= repositories.values
      found = false
      search_repositories.each do |repo|
        found = repo.has_subject? rdf_subject
        break if found
      end
      found
    end
    module_function :has_subject?

  end
end
