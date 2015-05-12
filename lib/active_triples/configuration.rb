module ActiveTriples
  class Configuration
    attr_accessor :inner_hash
    def initialize(options={})
      @inner_hash = Hash[options.to_a]
    end

    def merge(options)
      new_config = Configuration.new(options)
      new_config.properties.each do |property, reflection|
        current_property = properties[property] || reflection_factory.new(self, property)
        current_property.set reflection.value
      end
      self
    end
    
    def properties
      to_h.each_with_object({}) do |config_value, hsh|
        key = config_value.first
        hsh[key] = reflection_factory.new(self, key)
      end
    end

    def [](value)
      to_h[value]
    end

    def to_h
      @inner_hash.slice(*valid_config_options)
    end

    private

    def reflection_factory
      @reflection_factory ||= ReflectionFactory.new
    end

    def valid_config_options
      [:base_uri, :rdf_label, :type, :repository]
    end

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

    class MergeReflection < Reflection
      def set(value)
        object.inner_hash[key] = Array(object.inner_hash[key])
        object.inner_hash[key] |= Array(value)
      end
    end

    class ReflectionFactory
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
