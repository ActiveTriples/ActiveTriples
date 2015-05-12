module ActiveTriples
  require_relative 'configuration/reflection'
  require_relative 'configuration/merge_reflection'
  require_relative 'configuration/reflection_factory'
  ##
  # Class which contains configuration for RDFSources.
  class Configuration
    attr_accessor :inner_hash
    # @param [Hash] options the configuration options.
    def initialize(options={})
      @inner_hash = Hash[options.to_a]
    end

    # Merges this configuration with other configuration options. This uses
    # reflection setters to handle special cases like :type.
    #
    # @param [Hash] options configuration options to merge in.
    # @return [ActiveTriples::Configuration] the configuration object which is a
    #   result of merging.
    def merge(options)
      new_config = Configuration.new(options)
      new_config.reflections.each do |property, reflection|
        self.build_reflection(property).set reflection.value
      end
      self
    end
    
    # Returns a hash with keys as the configuration property and values as
    # reflections which know how to set a new value to it.
    # 
    # @return [Hash{Symbol => ActiveTriples::Configuration::Reflection}]
    def reflections
      to_h.each_with_object({}) do |config_value, hsh|
        key = config_value.first
        hsh[key] = build_reflection(key)
      end
    end

    # Returns the configured value for an option
    #
    # @return the configured value
    def [](value)
      to_h[value]
    end

    # Returns the available configured options as a hash.
    #
    # This filters the options the class is initialized with.
    #
    # @return [Hash{Symbol => String, ::RDF::URI}]
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
