require 'deprecation'
require 'active_model'
require 'active_support/core_ext/hash'

module ActiveTriples
  ##
  # Defines a generic RDF `Resource` as an RDF::Graph with property
  # configuration, accessors, and some other methods for managing
  # resources as discrete subgraphs which can be maintained by a Hydra
  # datastream model.
  #
  # Resources can be instances of ActiveTriples::Resource
  # directly, but more often they will be instances of subclasses with
  # registered properties and configuration. e.g.
  #
  #    class License < Resource
  #      configure repository: :default
  #      property :title, predicate: RDF::DC.title, class_name: RDF::Literal do |index|
  #        index.as :displayable, :facetable
  #      end
  #    end
  class Resource < RDF::Graph
    @@type_registry
    extend Configurable
    include Properties
    extend Deprecation
    extend  ActiveModel::Naming
    extend  ActiveModel::Translation
    include ActiveModel::Validations
    include ActiveModel::Conversion
    include ActiveModel::Serialization
    include ActiveModel::Serializers::JSON
    include NestedAttributes
    include Reflection
    attr_accessor :parent

    class << self
      def type_registry
        @@type_registry ||= {}
      end

      ##
      # Adapter for a consistent interface for creating a new Resource
      # from a URI. Similar functionality should exist in all objects
      # which can become a Resource.
      #
      # @param uri [#to_uri, String]
      # @param vals values to pass as arguments to ::new
      #
      # @return [ActiveTriples::Resource] a Resource with
      def from_uri(uri,vals=nil)
        new(uri, vals)
      end
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
    #    Resource.new(nil, parent)
    #
    # @see RDF::Graph
    def initialize(*args, &block)
      resource_uri = args.shift unless args.first.is_a?(Hash)
      self.parent = args.shift unless args.first.is_a?(Hash)
      set_subject!(resource_uri) if resource_uri
      super(*args, &block)
      reload
      # Append type to graph if necessary.
      self.get_values(:type) << self.class.type if self.class.type.kind_of?(RDF::URI) && type.empty?
    end

    ##
    # Returns the current object.
    #
    # @deprecated redundant, simply returns self.
    #
    # @return [self]
    def graph
      Deprecation.warn Resource, "graph is redundant & deprecated. It will be removed in ActiveTriples 0.2.0.", caller
      self
    end

    def final_parent
      @final_parent ||= begin
        parent = self.parent
        while parent && parent.parent && parent.parent != parent
          parent = parent.parent
        end
        parent
      end
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
      set_subject!(values.delete(:id)) if values.has_key?(:id) and node?
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
    # A string identifier for the resource
    def id
      node? ? nil : rdf_subject.to_s
    end

    def node?
      return true if rdf_subject.kind_of? RDF::Node
      false
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
    #    osu = ActiveTriples::Resource.new('http://dbpedia.org/resource/Oregon_State_University')
    #    osu.fetch
    #    osu.rdf_label.first
    #    # => "Oregon State University"
    #
    # @return [ActiveTriples::Resource] self
    def fetch
      load(rdf_subject)
      self
    end

    def persist!
      raise "failed when trying to persist to non-existant repository or parent resource" unless repository
      erase_old_resource
      repository << self
      @persisted = true
    end

    ##
    # Indicates if the resource is persisted.
    #
    # @see #persist
    # @return [true, false]
    def persisted?
      @persisted ||= false
      return (@persisted and parent.persisted?) if parent
      @persisted
    end

    ##
    # Repopulates the graph from the repository or parent resource.
    #
    # @return [true, false]
    def reload
      @term_cache ||= {}
      if self.class.repository == :parent
        return false if final_parent.nil?
      end
      self << repository.query(subject: rdf_subject)
      unless empty?
        @persisted = true
      end
      true
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
      get_term(args).set(values)
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
      get_term(args)
    end

    ##
    # Returns an array of values belonging to the property
    # requested. Elements in the array may RdfResource objects or a
    # valid datatype.
    def [](uri_or_term_property)
      get_term([uri_or_term_property])
    end


    def get_term(args)
      @term_cache ||= {}
      term = Term.new(self, args)
      @term_cache["#{term.send(:rdf_subject)}/#{term.property}"] ||= term
      @term_cache["#{term.send(:rdf_subject)}/#{term.property}"]
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

    def destroy
      clear
      persist! if repository
      parent.destroy_child(self) if parent
      @destroyed = true
    end
    alias_method :destroy!, :destroy
    
    ##
    # Indicates if the Resource has been destroyed.
    # 
    # @return [true, false]
    def destroyed?
      @destroyed ||= false
    end

    def destroy_child(child)
      statements.each do |statement|
        delete_statement(statement) if statement.subject == child.rdf_subject || statement.object == child.rdf_subject
      end
    end

    ##
    # Indicates if the record is 'new' (has not yet been persisted).
    #
    # @return [true, false]
    def new_record?
      not persisted?
    end

    ##
    # @return [String] the string representation of the resource
    def solrize
      node? ? rdf_label : rdf_subject.to_s
    end

    def mark_for_destruction
      @marked_for_destruction = true
    end

    def marked_for_destruction?
      @marked_for_destruction
    end

    protected

      #Clear out any old assertions in the repository about this node or statement
      # thus preparing to receive the updated assertions.
      def erase_old_resource
        if node?
          repository.statements.each do |statement|
            repository.send(:delete_statement, statement) if statement.subject == rdf_subject
          end
        else
          repository.delete [rdf_subject, nil, nil]
        end
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
      def self.id_persisted?(test_id)
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
      def self.uri_persisted?(test_uri)
        rdf_subject = test_uri.kind_of?(RDF::URI) ? test_uri : RDF::URI(test_uri)
        ActiveTriples::Repositories.has_subject?(rdf_subject)
      end

    private

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

      def default_labels
        [RDF::SKOS.prefLabel,
         RDF::DC.title,
         RDF::RDFS.label,
         RDF::SKOS.altLabel,
         RDF::SKOS.hiddenLabel]
      end

      ##
      # Return the repository (or parent) that this resource should
      # write to when persisting.
      #
      # @return [RDF::Repository, ActiveTriples::Resource] the target
      #   repository
      def repository
        @repository ||=
          if self.class.repository == :parent
            final_parent
          else
            Repositories.repositories[self.class.repository]
          end
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
        return uri_or_str.to_uri if uri_or_str.respond_to? :to_uri
        return uri_or_str if uri_or_str.kind_of? RDF::Node
        uri_or_str = uri_or_str.to_s
        return RDF::Node(uri_or_str[2..-1]) if uri_or_str.start_with? '_:'
        return RDF::URI(uri_or_str) if RDF::URI(uri_or_str).valid? and (URI.scheme_list.include?(RDF::URI.new(uri_or_str).scheme.upcase) or RDF::URI.new(uri_or_str).scheme == 'info')
        return RDF::URI(self.base_uri.to_s + (self.base_uri.to_s[-1,1] =~ /(\/|#)/ ? '' : '/') + uri_or_str) if base_uri && !uri_or_str.start_with?(base_uri.to_s)
        raise RuntimeError, "could not make a valid RDF::URI from #{uri_or_str}"
      end
  end
end
