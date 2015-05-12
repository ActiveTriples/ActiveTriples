module ActiveTriples
  class Configuration
    # Basic reflection which overrides the value for a key on the object.
    class Reflection
      attr_reader :object, :key
      def initialize(object, key)
        @object = object
        @key = key
      end

      def value
        object.inner_hash[key]
      end

      def set(value)
        object.inner_hash[key] = value
      end
    end
  end
end
