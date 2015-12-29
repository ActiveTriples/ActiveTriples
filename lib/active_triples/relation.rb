require 'active_support/core_ext/module/delegation'

module ActiveTriples
  ##
  # A `Relation` represents the values of a specific property/predicate on an
  # {RDFSource}. Each relation is a set ({Array}) of {RDF::Terms} that are
  # objects in the of source's triples of the form:
  #
  #   <{#parent}> <{#predicate}> [term] .
  #
  # Relations express a set of binary relationships (on a predicate) between 
  # the parent node and a term. 
  # 
  # When the term is a URI or Blank Node, it is represented in the results
  # {Array} as an {RDFSource} with a graph selected as a subgraph of the 
  # parent's. The triples in this subgraph are: (a) those whose subject is the
  # term; (b) ...
  #
  #
  # @see RDF::Term
  class Relation
    include Enumerable
    
    attr_accessor :parent, :value_arguments, :node_cache, :rel_args
    attr_reader :reflections

    delegate :<=>, :==, :===, :[], :each, :empty?, :equal, :inspect, :last, 
       :to_a, :to_ary, :to => :result

    ##
    # @param [ActiveTriples::RDFSource] parent_source
    # @param [Array<Symbol, Hash>] value_arguments  if a Hash is passed as the 
    #   final element, it is removed and set to `@rel_args`.
    def initialize(parent_source, value_arguments)
      self.parent = parent_source
      @reflections = parent_source.reflections
      self.rel_args ||= {}
      self.rel_args = value_arguments.pop if value_arguments.is_a?(Array) && 
                                             value_arguments.last.is_a?(Hash)
      self.value_arguments = value_arguments
    end

    ##
    # Empties the `Relation`, deleting any associated triples from `parent`.
    #
    # @return [Relation] self; a now empty relation
    def clear
      parent.delete([rdf_subject, predicate, nil])

      self
    end

    ##
    # Gives an {Array} containing the result set for the {Relation}.
    #
    # By default, {RDF::URI} and {RDF::Node} results are cast to `RDFSource`.
    # {Literal} results are given as their `#object` representations (e.g. 
    # {String}, {Date}.
    #
    # @example results with default casting
    #   parent << [parent.rdf_subject, predicate, 'my value']
    #   parent << [parent.rdf_subject, predicate, Date.today]
    #   parent << [parent.rdf_subject, predicate, RDF::URI('http://ex.org/#me')]
    #   parent << [parent.rdf_subject, predicate, RDF::Node.new]
    #   relation.result
    #   # => ["my_value", 
    #   #     Fri, 25 Sep 2015, 
    #   #     #<ActiveTriples::Resource:0x3f8...>, 
    #   #     #<ActiveTriples::Resource:0x3f8...>]
    #
    # When `cast?` is `false`, {RDF::Resource} values are left in their raw 
    # form. Similarly, when `#return_literals?` is `true`, literals are 
    # returned in their {RDF::Literal} form, preserving language tags, 
    # datatype, and value.
    #
    # @example results with `cast?` set to `false`
    #   relation.result
    #   # => ["my_value", 
    #   #     Fri, 25 Sep 2015,
    #   #     #<RDF::URI:0x3f8... URI:http://ex.org/#me>,
    #   #     #<RDF::Node:0x3f8...(_:g69843536054680)>]
    #
    # @example results with `return_literals?` set to `true`
    #   relation.result
    #   # => [#<RDF::Literal:0x3f8...("my_value")>,
    #   #     #<RDF::Literal::Date:0x3f8...("2015-09-25"^^<http://www.w3.org/2001/XMLSchema#date>)>,
    #   #     #<ActiveTriples::Resource:0x3f8...>, 
    #   #     #<ActiveTriples::Resource:0x3f8...>]
    # 
    # @return [Array<Object>] the result set
    def result
      return [] if predicate.nil?
      statements = parent.query(:subject => rdf_subject, 
                                :predicate => predicate)
      statements.each_with_object([]) do |x, collector|
        converted_object = convert_object(x.object)
        collector << converted_object unless converted_object.nil?
      end
    end

    ##
    # Adds values to the relation
    #
    # @param [Array<RDF::Resource>, RDF::Resource] values  an array of values
    #   or a single value. If not an {RDF::Resource}, the values will be 
    #   coerced to an {RDF::Literal} or {RDF::Node} by {RDF::Statement}
    #
    # @return [Relation] a relation containing the set values; i.e. `self`
    #
    # @raise [ActiveTriples::UndefinedPropertyError] if the property is not
    #   already an {RDF::Term} and is not defined in `#property_config`
    # 
    # @see http://www.rubydoc.info/github/ruby-rdf/rdf/RDF/Statement For 
    #   documentation on {RDF::Statement} and the handling of 
    #   non-{RDF::Resource} values.
    def set(values)
      raise UndefinedPropertyError.new(property, reflections) if predicate.nil?
      values = values.to_a if values.is_a? Relation
      values = [values].compact unless values.kind_of?(Array)

      clear
      values.each { |val| set_value(val) }

      parent.persist! if parent.persistence_strategy.is_a? ParentStrategy
      self
    end

    def build(attributes={})
      new_subject = attributes.fetch('id') { RDF::Node.new }
      make_node(new_subject).tap do |node|
        node.attributes = attributes.except('id')
        if parent.kind_of? List::ListResource
          parent.list << node
        elsif node.kind_of? RDF::List
          self.push node.rdf_subject
        else
          self.push node
        end
      end
    end

    def first_or_create(attributes={})
      result.first || build(attributes)
    end

    def delete(*values)
      values.each { |value| parent.delete([rdf_subject, predicate, value]) }
    end

    def <<(values)
      values = Array.wrap(result) | Array.wrap(values)
      self.set(values)
    end
    alias_method :push, :<<

    #
    def []=(index, value)
      values = Array.wrap(result)
      raise IndexError, "Index #{index} out of bounds." if values[index].nil?
      values[index] = value
      self.set(values)
    end

    # @todo find a way to simplify this?
    def property_config
      return type_property if is_type?
      
      reflections.reflect_on_property(property)
    end

    ##
    # noop
    def reset!; end

    ##
    # Returns the property for the Relation. This may be a registered 
    # property key or an {RDF::URI}.
    #
    # @return [Symbol, RDF::URI]  the property for this Relation.
    # @see #predicate
    def property
      value_arguments.last
    end

    ##
    # Gives the predicate used by the Relation. Values of this object are 
    # those that match the pattern `<rdf_subject> <predicate> [value] .`
    #
    # @return [RDF::Term, nil] the predicate for this relation; nil if 
    #   no predicate can be found
    #
    # @see #property
    def predicate
      return property if property.is_a?(RDF::Term)
      property_config[:predicate] if is_property?
    end

    protected

      def node_cache
        @node_cache ||= {}
      end

      def is_property?
        reflections.has_property?(property) || is_type?
      end

      def is_type?
        (property == RDF.type || property.to_s == "type") && 
        (!reflections.kind_of?(RDFSource) || !is_property?)
      end

      def set_value(val)
        object = val
        val = val.resource if val.respond_to?(:resource)
        val = value_to_node(val)
        if val.kind_of? RDFSource
          node_cache[val.rdf_subject] = nil
          add_child_node(val, object)
          return
        end
        val = val.to_uri if val.respond_to? :to_uri
        raise ValueError, val unless val.kind_of? RDF::Term
        parent.insert [rdf_subject, predicate, val]
      end

      def type_property
        { :predicate => RDF.type, :cast => false }
      end

      def value_to_node(val)
        valid_datatype?(val) ? RDF::Literal(val) : val
      end

      def add_child_node(resource, object = nil)
        parent.insert [rdf_subject, predicate, resource.rdf_subject]

        unless resource.frozen? || 
               resource == parent || 
               (parent.persistence_strategy.is_a?(ParentStrategy) && 
                resource == parent.persistence_strategy.final_parent)
          resource.set_persistence_strategy(ParentStrategy)
          resource.parent = parent 
        end

        self.node_cache[resource.rdf_subject] = (object ? object : resource)
        resource.persist! if resource.persistence_strategy.is_a? ParentStrategy
      end

      def valid_datatype?(val)
        case val
        when String, Date, Time, Numeric, Symbol, TrueClass, FalseClass then true
        else false
        end
      end

      # Converts an object to the appropriate class.
      def convert_object(value)
        case value
        when RDFSource
          value
        when RDF::Literal
          return_literals? ? value : value.object
        when RDF::Resource
          make_node(value)
        else
          value
        end
      end

      ##
      # Build a child resource or return it from this object's cache
      #
      # Builds the resource from the class_name specified for the
      # property.
      def make_node(value)
        return value unless cast?
        klass = class_for_value(value)
        value = RDF::Node.new if value.nil?
        node = node_cache[value] if node_cache[value]
        node ||= klass.from_uri(value,parent)
        return nil if (is_property? && property_config[:class_name]) && (class_for_value(value) != class_for_property)
        self.node_cache[value] ||= node
        node
      end

      def cast?
        return true unless is_property? || (rel_args && rel_args[:cast])
        return rel_args[:cast] if rel_args.has_key?(:cast)
        !!property_config[:cast]
      end

      def return_literals?
        rel_args && rel_args[:literal]
      end

      def final_parent
        @final_parent ||= begin
          parent = self.parent
          while parent != parent.parent && parent.parent
            parent = parent.parent
          end
          return parent.datastream if parent.respond_to?(:datastream) && parent.datastream
          parent
        end
      end

      def class_for_value(v)
        uri_class(v) || class_for_property
      end

      def uri_class(v)
        v = RDF::URI.new(v) if v.kind_of? String
        type_uri = parent.query([v, RDF.type, nil]).to_a.first.try(:object)
        Resource.type_registry[type_uri]
      end

      def class_for_property
        klass = property_config[:class_name] if is_property?
        klass ||= Resource
        klass = ActiveTriples.class_from_string(klass, final_parent.class) if
          klass.kind_of? String
        klass
      end

      ##
      # @return [RDF::Term] the subject of the relation
      def rdf_subject
        if value_arguments.length < 1 || value_arguments.length > 2
          raise(ArgumentError, 
                "wrong number of arguments (#{value_arguments.length} for 1-2)")
        end

        value_arguments.length > 1 ? value_arguments.first : parent.rdf_subject
      end

    public

    ##
    # An error class for unallowable values in relations.
    class ValueError < ArgumentError
      # @!attribute [r] value
      attr_reader :value

      ##
      # @param value [Object]
      def initialize(value)
        @value = value
      end

      ##
      # @return [String]
      def message
        'value must be an RDF URI, Node, Literal, or a valid datatype. '\
        "See RDF::Literal.\n\tYou provided #{value.inspect}"
      end
    end
  end
end
