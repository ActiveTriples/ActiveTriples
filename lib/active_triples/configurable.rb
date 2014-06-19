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
      nil
    end

    def rdf_label
      nil
    end

    def type
      nil
    end

    ##
    # @deprecated use `configure type:` instead.
    def rdf_type(value)
      Deprecation.warn Configurable, "rdf_type is deprecated and will be removed in active-fedora 8.0.0. Use configure type: instead.", caller
      configure type: value
    end

    def repository
      :parent
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
      {
        base_uri: options[:base_uri],
        rdf_label: options[:rdf_label],
        type: options[:type],
        repository: options[:repository]
      }.each do |name, value|
        if value
          value = self.send("transform_#{name}", value) if self.respond_to?("transform_#{name}")
          define_singleton_method(name) do
            value
          end
        end
      end
    end

    def transform_type(value)
      RDF::URI.new(value).tap do |value|
        Resource.type_registry[value] = self
      end
    end
  end
end
