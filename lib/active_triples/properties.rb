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
    extend ActiveSupport::Concern

    included do
      initialize_generated_modules
    end

    ##
    # Registers properties for Resource-like classes
    # @param [Symbol]  name of the property (and its accessor methods)
    # @param [Hash]  opts for this property, must include a :predicate
    # @yield [index] index sets solr behaviors for the property
    def property(name, opts={}, &block)
      self.config[name] = NodeConfig.new(name, opts[:predicate], opts.except(:predicate)).tap do |config|
        config.with_index(&block) if block_given?
      end
      register_property(name)
    end

    module ClassMethods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules # :nodoc:
        generated_property_methods
      end

      def generated_property_methods
        @generated_property_methods ||= begin
          mod = const_set(:GeneratedPropertyMethods, Module.new)
          include mod
          mod
        end
      end

      ##
      # Registers properties for Resource-like classes
      # @param [Symbol]  name of the property (and its accessor methods)
      # @param [Hash]  opts for this property, must include a :predicate
      # @yield [index] index sets solr behaviors for the property
      def property(name, opts={}, &block)
        raise ArgumentError, "#{name} is a keyword and not an acceptable property name." if protected_property_name? name
        reflection = PropertyBuilder.build(self, name, opts, &block)
        Reflection.add_reflection self, name, reflection
      end
      
      def protected_property_name?(name)
        reject = self.instance_methods.map! { |s| s.to_s.gsub(/=$/, '').to_sym }
        reject -= properties.keys.map { |k| k.to_sym }
        reject.include? name
      end

      ##
      # Given a property name or a predicate, return the configuration
      # for the matching property.
      #
      # @param term [#to_sym, RDF::Resource] a property name to predicate
      #
      # @return [ActiveTriples::NodeConfig]
      def config_for_term_or_uri(term)
        return properties[term.to_s] unless term.kind_of? RDF::Resource
        properties.each_value { |v| return v if v.predicate == term.to_uri }
      end

      ##
      # List the property names registered to the class.
      #
      # @return [Array<Symbol>] list of the symbolized names of registered
      #   properties
      def fields
        properties.keys.map(&:to_sym)
      end
    end
  end
end
