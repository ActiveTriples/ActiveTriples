module ActiveTriples
  ##
  # A value object to encapsulate what a Property is. Instantiate with a hash of
  # options.
  #
  # @todo Should we enforce the interface on the various attributes that are set?
  class Property
    def initialize(options = {})
      self.name = options.fetch(:name)
      self.attributes = options.except(:name)
    end

    # @return Symbol
    attr_reader :name

    # @return Boolean
    def cast
      attributes.fetch(:cast, false)
    end

    # @return Class
    def class_name
      attributes[:class_name]
    end

    # @return RDF::Vocabulary::Term
    def predicate
      attributes[:predicate]
    end

    private

    attr_writer :name
    attr_accessor :attributes

    alias_method :to_h, :attributes

    # Returns the property's configuration values. Will not return #name, which is
    # meant to only be accessible via the accessor.
    # @return [Hash] Configuration values for this property.
    public :to_h
  end
end
