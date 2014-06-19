require 'active_support/core_ext/hash'

module ActiveTriples
  ##
  # Implements property configuration common to Rdf::Resource,
  # RDFDatastream, and others.  It does its work at the class level,
  # and is meant to be extended.
  #
  # Define properties at the class level with:
  #
  #    property :title, predicate: RDF::DC.title, class_name: ResourceClass
  #
  module Properties
    attr_accessor :config

    ##
    # Registers properties for Resource-like classes
    # @param [Symbol]  name of the property (and its accessor methods)
    # @param [Hash]  opts for this property, must include a :predicate
    # @yield [index] index sets solr behaviors for the property
    def property(name, opts={}, &block)
      self.config[name] = NodeConfig.new(name, opts[:predicate], opts.except(:predicate)).tap do |config|
        config.with_index(&block) if block_given?
      end
      behaviors = config[name].behaviors.flatten if config[name].behaviors and not config[name].behaviors.empty?
      register_property(name)
    end

    ##
    # Returns the properties registered to the class and their 
    # configurations.
    #
    # @return [ActiveSupport::HashWithIndifferentAccess{String => ActiveTriples::NodeConfig}]
    def config
      @config ||= if superclass.respond_to? :config
        superclass.config.dup
      else
        {}.with_indifferent_access
      end
    end

    alias_method :properties, :config
    alias_method :properties=, :config=

    ##
    # Given a property name or a predicate, return the configuration
    # for the matching property.
    #
    # @param term [#to_sym, RDF::Resource] a property name to predicate
    #
    # @return [ActiveTriples::NodeConfig]
    def config_for_term_or_uri(term)
      return config[term.to_sym] unless term.kind_of? RDF::Resource
      config.each { |k, v| return v if v.predicate == term.to_uri }
    end

    ##
    # List the property names registered to the class.
    #
    # @return [Array<Symbol>] list of the symbolized names of registered
    #   properties
    def fields
      properties.keys.map(&:to_sym)
    end

    private

    ##
    # Private method for creating accessors for a given property.
    #
    # @param [#to_s] name Name of the accessor to be created, 
    #   get/set_value is called on the resource using this.
    def register_property(name)
      parent = Proc.new{self}
      # parent = Proc.new{resource} if self < ActiveFedora::Datastream
      define_method "#{name}=" do |*args|
        instance_eval(&parent).set_value(name.to_sym, *args)
      end
      define_method name do
        instance_eval(&parent).get_values(name.to_sym)
      end
    end
  end
end
