module ActiveTriples
  ##
  # Super class which provides a simple property DSL for defining property ->
  # predicate mappings.
  class Schema
    class << self
      # @param [Symbol] property The property name on the object.
      # @param [Hash] options Options for the property.
      # @option options [RDF::URI] :predicate The predicate to map the property
      #   to.
      def property(property, options)
        properties << Property.new(options.merge(:name => property))
      end

      def properties
        @properties ||= []
      end
    end
  end
end
