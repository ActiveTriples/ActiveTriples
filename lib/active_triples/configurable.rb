require 'deprecation'

module ActiveTriples
  ##
  # Module to include configurable class-wide properties common to
  # Resource and RDFDatastream. It does its work at the class level,
  # and is meant to be extended.
  #
  # Define properties at the class level with:
  #
  #    configure base_uri: "http://oregondigital.org/resource/", repository: :default
  # Available properties are base_uri, rdf_label, type, and repository
  module Configurable
    extend Deprecation
    def base_uri
      configuration[:base_uri]
    end

    def rdf_label
      configuration[:rdf_label]
    end

    def type
      configuration[:type]
    end

    def configuration
      @configuration ||= Configuration.new
    end

    ##
    # @deprecated use `configure type:` instead.
    def rdf_type(value)
      Deprecation.warn Configurable, "rdf_type is deprecated and will be removed in active-fedora 8.0.0. Use configure type: instead.", caller
      configure type: value
    end

    def repository
      configuration[:repository] || :parent
    end

    ##
    # API for configuring class properties on a Resource. This is an 
    # alternative to overriding the methods in this module.
    #
    # Can configure the following values:
    #  - base_uri (allows passing slugs to the Resource initializer 
    #    in place of fully qualified URIs)
    #  - rdf_label (overrides default label predicates)
    #  - type (a default rdf:type to include when initializing a
    #    new Resource)
    #  - repository (the target persist location to for the Resource)
    # 
    #   configure base_uri: "http://oregondigital.org/resource/", repository: :default
    #
    # @param options [Hash]
    def configure(options = {})
      options = options.map do |key, value|
        if self.respond_to?("transform_#{key}")
          value = self.__send__("transform_#{key}", value)
        end
        [key, value]
      end
      @configuration = configuration.merge(options)
    end

    def transform_type(values)
      Array(values).map do |value|
        RDF::URI.new(value).tap do |uri|
          Resource.type_registry[uri] = self
        end
      end
    end
  end
end
