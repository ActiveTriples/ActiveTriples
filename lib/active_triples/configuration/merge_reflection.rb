module ActiveTriples
  class Configuration
    class MergeReflection < Reflection
      def set(value)
        object.inner_hash[key] = Array(object.inner_hash[key])
        object.inner_hash[key] |= Array(value)
      end
    end
  end
end
