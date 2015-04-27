require 'active_model'
require 'active_support/core_ext/hash'

module ActiveTriples
  ##
  # Defines a concern for managing {RDF::Graph} driven Resources as discrete,
  # stateful graphs using ActiveModel-style objects.
  #
  # An `RDFSource` models a resource ({RDF::Resource}) with a state that may
  # change over time. The current state is represented by an {RDF::Graph},
  # accessible as {#graph}. The source is an {RDF::Resource} represented by
  # {#rdf_subject}, which may be either an {RDF::URI} or an {RDF::Node}.
  #
  # The graph of a source may contain contain arbitrary triples, including full
  # representations of the state of other sources. The triples in the graph
  # should be limited to statements that have bearing on the resource's state.
  #
  # Properties may be defined on inheriting classes to configure accessor
  # methods for predicates.
  #
  # @example
  #    class License
  #      include Active::Triples::RDFSource
  #
  #      configure repository: :default
  #      property :title, predicate: RDF::DC.title, class_name: RDF::Literal
  #    end
  #
  # @see http://www.w3.org/TR/2014/REC-rdf11-concepts-20140225/#change-over-time
  #   RDF Concepts and Abstract Syntax comment on "RDF source"
  # @see http://www.w3.org/TR/ldp/#dfn-linked-data-platform-rdf-source an
  #   example of the RDF source concept as defined in the LDP specification
  #
  # @see ActiveModel
  # @see RDF::Resource
  # @see RDF::Queryable
  module RDFSource
    extend ActiveSupport::Concern

    include NestedAttributes
    include Persistable
    include Properties
    include Reflection
    include RDF::Value
    include RDF::Countable
    include RDF::Enumerable
    include RDF::Durable
    include RDF::Queryable
    include RDF::Mutable
    include ActiveModel::Validations
    include ActiveModel::Conversion
    include ActiveModel::Serialization
    include ActiveModel::Serializers::JSON

    def type_registry
      @@type_registry ||= {}
    end
    module_function :type_registry

    included do
      extend Configurable
      extend ActiveModel::Naming
      extend ActiveModel::Translation
      extend ActiveModel::Callbacks

      validate do
        errors.add(:base, 'The underlying graph must be valid') unless
          graph.valid?
      end

      delegate :each, :load!, :count, :has_statement?, :to=> :graph

      define_model_callbacks :persist
    end

    ##
    # Specifies whether the object is currently writable.
    #
    # @return [true, false]
    def writable?
      !frozen?
    end

    ##
    # Initialize an instance of this resource class. Defaults to a
    # blank node subject. In addition to RDF::Graph parameters, you
    # can pass in a URI and/or a parent to build a resource from a
    # existing data.
    #
    # You can pass in only a parent with:
    #    new(nil, parent)
    #
    # @see RDF::Graph
    # @todo move this logic out to a Builder?
    def initialize(*args, &block)
      resource_uri = args.shift unless args.first.is_a?(Hash)
      unless args.first.is_a?(Hash) || args.empty?
        set_persistence_strategy(ParentStrategy)
        persistence_strategy.parent = args.shift
      else
        set_persistence_strategy(RepositoryStrategy)
      end
      @graph = RDF::Graph.new(*args, &block)
      set_subject!(resource_uri) if resource_uri

      reload
      # Append type to graph if necessary.
      self.get_values(:type) << self.class.type if
        self.class.type.kind_of?(RDF::URI) && type.empty?
    end

    ##
    # Delegate parent to the persistence strategy if possible
    #
    # @todo establish a better pattern for this. `#parent` has been a public method
    #   in the past, but it's probably time to deprecate it.
    def parent
      persistence_strategy.respond_to?(:parent) ? persistence_strategy.parent : nil
    end

    ##
    # @todo deprecate/remove
    # @see #parent
    def parent=(parent)
      persistence_strategy.respond_to?(:parent=) ? (persistence_strategy.parent = parent) : nil
    end

    def attributes
      attrs = {}
      attrs['id'] = id if id
      fields.map { |f| attrs[f.to_s] = get_values(f) }
      unregistered_predicates.map { |uri| attrs[uri.to_s] = get_values(uri) }
      attrs
    end

    def serializable_hash(options = nil)
      attrs = (fields.map { |f| f.to_s }) << 'id'
      hash = super(:only => attrs)
      unregistered_predicates.map { |uri| hash[uri.to_s] = get_values(uri) }
      hash
    end

    def reflections
      self.class
    end

    def attributes=(values)
      raise ArgumentError, "values must be a Hash, you provided #{values.class}" unless values.kind_of? Hash
      values = values.with_indifferent_access
      id = values.delete(:id)
      set_subject!(id) if id && node?
      values.each do |key, value|
        if reflections.reflect_on_property(key)
          set_value(rdf_subject, key, value)
        elsif nested_attributes_options.keys.map { |k| "#{k}_attributes" }.include?(key)
          send("#{key}=".to_sym, value)
        else
          raise ArgumentError, "No association found for name `#{key}'. Has it been defined yet?"
        end
      end
    end

    ##
    # Returns a serialized string representation of self.
    # Extends the base implementation builds a JSON-LD context if the
    # specified format is :jsonld and a context is provided by
    # #jsonld_context
    #
    # @see RDF::Enumerable#dump
    #
    # @param args [Array<Object>]
    # @return [String]
    def dump(*args)
      if args.first == :jsonld and respond_to?(:jsonld_context)
        args << {} unless args.last.is_a?(Hash)
        args.last[:context] ||= jsonld_context
      end
      super
    end

    ##
    # @return [RDF::URI, RDF::Node] a URI or Node which the resource's
    #   properties are about.
    def rdf_subject
      @rdf_subject ||= RDF::Node.new
    end
    alias_method :to_term, :rdf_subject

    ##
    # @return [String, nil] A string identifier for the resource; nil if the
    #   resource is a node
    def id
      node? ? nil : rdf_subject.to_s
    end

    ##
    # @return [Boolean]
    # @see RDF::Term#node?
    def node?
      rdf_subject.node?
    end

    ##
    # @return [String, nil] the base URI the resource will use when
    #   setting its subject. `nil` if none is used.
    def base_uri
      self.class.base_uri
    end

    def type
      self.get_values(:type).to_a
    end

    def type=(type)
      raise "Type must be an RDF::URI" unless type.kind_of? RDF::URI
      self.update(RDF::Statement.new(rdf_subject, RDF.type, type))
    end

    ##
    # Looks for labels in various default fields, prioritizing
    # configured label fields.
    def rdf_label
      labels = Array(self.class.rdf_label)
      labels += default_labels
      labels.each do |label|
        values = get_values(label)
        return values unless values.empty?
      end
      node? ? [] : [rdf_subject.to_s]
    end

    ##
    # Lists fields registered as properties on the object.
    #
    # @return [Array<Symbol>] the list of registered properties.
    def fields
      properties.keys.map(&:to_sym).reject{|x| x == :type}
    end

    ##
    # Load data from the #rdf_subject URI. Retrieved data will be
    # parsed into the Resource's graph from available RDF::Readers
    # and available from property accessors if if predicates are
    # registered.
    #
    #    osu = new('http://dbpedia.org/resource/Oregon_State_University')
    #    osu.fetch
    #    osu.rdf_label.first
    #    # => "Oregon State University"
    #
    # @return [ActiveTriples::Entity] self
    def fetch
      load(rdf_subject)
      self
    end

    ##
    # Adds or updates a property with supplied values.
    #
    # Handles two argument patterns. The recommended pattern is:
    #    set_value(property, values)
    #
    # For backwards compatibility, there is support for explicitly
    # passing the rdf_subject to be used in the statement:
    #    set_value(uri, property, values)
    #
    # @note This method will delete existing statements with the correct subject and predicate from the graph
    def set_value(*args)
      # Add support for legacy 3-parameter syntax
      if args.length > 3 || args.length < 2
        raise ArgumentError, "wrong number of arguments (#{args.length} for 2-3)"
      end
      values = args.pop
      get_relation(args).set(values)
    end

    ##
    # Adds or updates a property with supplied values.
    #
    # @note This method will delete existing statements with the correct subject and predicate from the graph
    def []=(uri_or_term_property, value)
      self[uri_or_term_property].set(value)
    end

    ##
    # Returns an array of values belonging to the property
    # requested. Elements in the array may RdfResource objects or a
    # valid datatype.
    #
    # Handles two argument patterns. The recommended pattern is:
    #    get_values(property)
    #
    # For backwards compatibility, there is support for explicitly
    # passing the rdf_subject to be used in th statement:
    #    get_values(uri, property)
    def get_values(*args)
      get_relation(args)
    end

    ##
    # Returns an array of values belonging to the property
    # requested. Elements in the array may RdfResource objects or a
    # valid datatype.
    def [](uri_or_term_property)
      get_relation([uri_or_term_property])
    end

    def get_relation(args)
      @relation_cache ||= {}
      rel = Relation.new(self, args)
      @relation_cache["#{rel.send(:rdf_subject)}/#{rel.property}/#{rel.rel_args}"] ||= rel
      @relation_cache["#{rel.send(:rdf_subject)}/#{rel.property}/#{rel.rel_args}"]
    end

    ##
    # Set a new rdf_subject for the resource.
    #
    # This raises an error if the current subject is not a blank node,
    # and returns false if it can't figure out how to make a URI from
    # the param. Otherwise it creates a URI for the resource and
    # rebuilds the graph with the updated URI.
    #
    # Will try to build a uri as an extension of the class's base_uri
    # if appropriate.
    #
    # @param [#to_uri, #to_s] uri_or_str the uri or string to use
    def set_subject!(uri_or_str)
      raise "Refusing update URI when one is already assigned!" unless node? or rdf_subject == RDF::URI(nil)
      # Refusing set uri to an empty string.
      return false if uri_or_str.nil? or (uri_or_str.to_s.empty? and not uri_or_str.kind_of? RDF::URI)
      # raise "Refusing update URI! This object is persisted to a datastream." if persisted?
      old_subject = rdf_subject
      @rdf_subject = get_uri(uri_or_str)

      each_statement do |statement|
        if statement.subject == old_subject
          delete(statement)
          self << RDF::Statement.new(rdf_subject, statement.predicate, statement.object)
        elsif statement.object == old_subject
          delete(statement)
          self << RDF::Statement.new(statement.subject, statement.predicate, rdf_subject)
        end
      end
    end

    def destroy_child(child)
      statements.each do |statement|
        delete_statement(statement) if statement.subject == child.rdf_subject || statement.object == child.rdf_subject
      end
    end

    ##
    # Indicates if the record is 'new' (has not yet been persisted).
    #
    # @return [Boolean]
    def new_record?
      not persisted?
    end

    def mark_for_destruction
      @marked_for_destruction = true
    end

    def marked_for_destruction?
      @marked_for_destruction
    end

    private

      def graph
        @graph
      end

      ######
      ## BEGIN Move these methods to `Properties`
      ######

      ##
      # Returns the properties registered and their configurations.
      #
      # @return [ActiveSupport::HashWithIndifferentAccess{String => ActiveTriples::NodeConfig}]
      def properties
        _active_triples_config
      end

      ##
      # List of RDF predicates registered as properties on the object.
      #
      # @return [Array<RDF::URI>]
      def registered_predicates
        properties.values.map { |config| config.predicate }
      end

      ##
      # List of RDF predicates used in the Resource's triples, but not
      # mapped to any property or accessor methods.
      #
      # @return [Array<RDF::URI>]
      def unregistered_predicates
        preds = registered_predicates
        preds << RDF.type
        predicates.select { |p| !preds.include? p }
      end

      ##
      # Given a predicate which has been registered to a property,
      # returns the name of the matching property.
      #
      # @param predicate [RDF::URI]
      #
      # @return [String, nil] the name of the property mapped to the
      #   predicate provided
      def property_for_predicate(predicate)
        properties.each do |property, values|
          return property if values[:predicate] == predicate
        end
        return nil
      end

      ######
      ## END Move these methods to `Properties`
      ######

      def default_labels
        [RDF::SKOS.prefLabel,
         RDF::DC.title,
         RDF::RDFS.label,
         RDF::SKOS.altLabel,
         RDF::SKOS.hiddenLabel]
      end

      ##
      # Takes a URI or String and aggressively tries to convert it into
      # an RDF term. If a String is given, first tries to interpret it
      # as a valid URI, then tries to append it to base_uri. Finally,
      # raises an error if no valid term can be built.
      #
      # The argument must be an RDF::Node, an object that responds to
      # #to_uri, a String that represents a valid URI, or a String that
      # appends to the Resource's base_uri to create a valid URI.
      #
      # @TODO: URI.scheme_list is naive and incomplete. Find a better
      #   way to check for an existing scheme.
      #
      # @param uri_or_str [RDF::Resource, String]
      #
      # @return [RDF::Resource] A term
      # @raise [RuntimeError] no valid RDF term could be built
      def get_uri(uri_or_str)
        return uri_or_str.to_term if uri_or_str.respond_to? :to_term
        return uri_or_str if uri_or_str.is_a? RDF::Node
        uri_or_node = RDF::Resource.new(uri_or_str)
        return uri_or_node if uri_or_node.valid?
        uri_or_str = uri_or_str.to_s
        return RDF::URI(base_uri.to_s) / uri_or_str if base_uri && !uri_or_str.start_with?(base_uri.to_s)
        raise RuntimeError, "could not make a valid RDF::URI from #{uri_or_str}"
      end

    public

    module ClassMethods
      ##
      # Adapter for a consistent interface for creating a new Resource
      # from a URI. Similar functionality should exist in all objects
      # which can become a Resource.
      #
      # @param uri [#to_uri, String]
      # @param args values to pass as arguments to ::new
      #
      # @return [ActiveTriples::Entity] a Resource with the given uri
      def from_uri(uri, *args)
        new(uri, *args)
      end

      ##
      # Test if the rdf_subject that would be generated using a
      # specific ID is already in use in the triplestore.
      #
      # @param [Integer, #read] ID to test
      #
      # @return [TrueClass, FalseClass] true, if the ID is in
      #    use in the triplestore; otherwise, false.
      #    NOTE: If the ID is in use in an object not yet
      #          persisted, false will be returned presenting
      #          a window of opportunity for an ID clash.
      def id_persisted?(test_id)
        rdf_subject = self.new(test_id).rdf_subject
        ActiveTriples::Repositories.has_subject?(rdf_subject)
      end

      ##
      # Test if the rdf_subject that would be generated using a
      # specific URI is already in use in the triplestore.
      #
      # @param [String, RDF::URI, #read] URI to test
      #
      # @return [TrueClass, FalseClass] true, if the URI is in
      #    use in the triplestore; otherwise, false.
      #    NOTE: If the URI is in use in an object not yet
      #          persisted, false will be returned presenting
      #          a window of opportunity for an ID clash.
      def uri_persisted?(test_uri)
        rdf_subject = test_uri.kind_of?(RDF::URI) ? test_uri : RDF::URI(test_uri)
        ActiveTriples::Repositories.has_subject?(rdf_subject)
      end
    end
  end
end
