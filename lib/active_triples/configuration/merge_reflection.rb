module ActiveTriples
  class Configuration
    # Reflection which sets a value by turning the original into an array and
    # appending the given value to it.
    #
    # This enables multiple types to be set on an object, for example.
    class MergeReflection < Reflection
      def set(value)
        object.inner_hash[key] = Array(object.inner_hash[key])
        object.inner_hash[key] |= Array(value)
      end
    end
  end
end
