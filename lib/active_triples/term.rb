require 'active_support/core_ext/module/delegation'

module ActiveTriples
  class Term

    attr_accessor :parent, :value_arguments, :node_cache, :term_args
    attr_reader :reflections

    delegate *(Array.public_instance_methods - [:send, :__send__, :__id__, :class, :object_id] + [:as_json]), :to => :result

    def initialize(parent_resource, value_arguments)
      self.parent = parent_resource
      @reflections = parent_resource.reflections
      self.term_args ||= {}
      self.value_arguments = value_arguments
    end

    def value_arguments=(value_args)
      if value_args.kind_of?(Array) && value_args.last.kind_of?(Hash)
        self.term_args = value_args.pop
      end
      @value_arguments = value_args
    end

    def clear
      set(nil)
    end

    def result(convert=true)
      results = parent.query(:subject => rdf_subject, :predicate => predicate)
      convert ? convert(results) : results.to_a
    end

    def convert(results)
      results.map { |x| convert_object(x.object) }
    end

    def set(values)
      values = [values].compact unless values.kind_of?(Array)
      values = values.to_a if values.class == Term
      empty_property
      values.each do |val|
        set_value(val)
      end
      parent.persist! if parent.class.repository == :parent && parent.send(:repository)
    end

    def empty_property
      parent.query([rdf_subject, predicate, nil]).each_statement do |statement|
        if !uri_class(statement.object) || uri_class(statement.object) == class_for_property
          parent.delete(statement)
        end
      end
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
      values.each do |value|
        parent.delete([rdf_subject, predicate, value])
      end
    end

    def << (values)
      values = Array.wrap(result) | Array.wrap(values)
      self.set(values)
    end

    alias_method :push, :<<

    def []=(index, value)
      values = Array.wrap(result)
      raise IndexError, "Index #{index} out of bounds." if values[index].nil?
      values[index] = value
      self.set(values)
    end

    def property_config
      return type_property if (property == RDF.type || property.to_s == "type") && (!reflections.kind_of?(Resource) || !reflections.reflect_on_property(property))
      reflections.reflect_on_property(property)
    end

    def type_property
      { :predicate => RDF.type, :cast => false }
    end

    def reset!
    end

    def property
      value_arguments.last
    end

    protected

      def node_cache
        @node_cache ||= {}
      end

      def set_value(val)
        object = val
        val = val.resource if val.respond_to?(:resource)
        val = value_to_node(val)
        if val.kind_of? Resource
          node_cache[val.rdf_subject] = nil
          add_child_node(val, object)
          return
        end
        val = val.to_uri if val.respond_to? :to_uri
        raise "value must be an RDF URI, Node, Literal, or a valid datatype. See RDF::Literal.\n\tYou provided #{val.inspect}" unless
          val.kind_of? RDF::Value or val.kind_of? RDF::Literal
        parent.insert [rdf_subject, predicate, val]
      end

      def value_to_node(val)
        valid_datatype?(val) ? RDF::Literal(val) : val
      end

      def add_child_node(resource,object=nil)
        parent.insert [rdf_subject, predicate, resource.rdf_subject]
        resource.parent = parent unless resource.frozen?
        self.node_cache[resource.rdf_subject] = (object ? object : resource)
        resource.persist! if resource.class.repository == :parent
      end

      def predicate
        property.kind_of?(RDF::URI) ? property : property_config[:predicate]
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
        return nil if (property_config && property_config[:class_name]) && (class_for_value(value) != class_for_property)
        self.node_cache[value] ||= node
        node
      end

      def cast?
        return true unless property_config || (term_args && term_args[:cast])
        return term_args[:cast] if term_args.has_key?(:cast)
        !!property_config[:cast]
      end

      def return_literals?
        term_args && term_args[:literal]
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
        klass = property_config[:class_name] if property_config
        klass ||= Resource
        klass = ActiveTriples.class_from_string(klass, final_parent.class) if klass.kind_of? String
        klass
      end

      def rdf_subject
        raise ArgumentError, "wrong number of arguments (#{value_arguments.length} for 1-2)" if value_arguments.length < 1 || value_arguments.length > 2
        if value_arguments.length > 1
          value_arguments.first
        else
          parent.rdf_subject
        end
      end

  end
end
