module ActiveTriples
  require_relative 'configuration/reflection'
  require_relative 'configuration/merge_reflection'
  require_relative 'configuration/reflection_factory'
  class Configuration
    attr_accessor :inner_hash
    def initialize(options={})
      @inner_hash = Hash[options.to_a]
    end

    def merge(options)
      new_config = Configuration.new(options)
      new_config.reflections.each do |property, reflection|
        self.build_reflection(property).set reflection.value
      end
      self
    end
    
    def reflections
      to_h.each_with_object({}) do |config_value, hsh|
        key = config_value.first
        hsh[key] = build_reflection(key)
      end
    end

    def [](value)
      to_h[value]
    end

    def to_h
      @inner_hash.slice(*valid_config_options)
    end

    protected

    def build_reflection(key)
      reflection_factory.new(self, key)
    end

    private

    def reflection_factory
      @reflection_factory ||= ReflectionFactory.new
    end

    def valid_config_options
      [:base_uri, :rdf_label, :type, :repository]
    end
  end

end
