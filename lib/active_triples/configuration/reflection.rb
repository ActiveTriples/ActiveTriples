module ActiveTriples
  class Configuration
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
