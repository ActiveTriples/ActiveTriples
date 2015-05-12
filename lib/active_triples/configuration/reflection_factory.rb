module ActiveTriples
  class Configuration
    ## Returns a reflection appropriate to a given configuration property.
    class ReflectionFactory
      # @return [MergeReflection, Reflection]
      def new(object, name)
        if merge_configs.include?(name)
          merge_reflection.new(object, name)
        else
          reflection.new(object, name)
        end
      end

      def merge_reflection
        MergeReflection
      end

      def reflection
        Reflection
      end

      def merge_configs
        [:type]
      end
    end
  end
end
