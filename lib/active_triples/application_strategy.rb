module ActiveTriples
  ##
  # Default application strategy which just copies all configured properties
  # from a data property to a new resource, assuming it supports the #property
  # interface.
  class ApplicationStrategy
    class << self
      def apply(resource, property)
        resource.property property.name, property.to_h
      end
    end
  end
end
