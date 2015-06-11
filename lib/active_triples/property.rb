module ActiveTriples
  ##
  # A value object to encapsulate what a Property is. Instantiate with a hash of
  # options.
  class Property < OpenStruct
    # Returns the property's configuration values. Will not return #name, which is
    # meant to only be accessible via the accessor.
    # @return [Hash] Configuration values for this property.
    def to_h
      super.except(:name)
    end
  end
end
