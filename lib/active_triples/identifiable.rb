require 'active_support'
require 'active_support/core_ext/module/delegation'

module ActiveTriples::Identifiable
  extend ActiveSupport::Concern

  delegate :rdf_subject, :type, to: :resource

  ##
  # @return [ActiveTriples::Resource] a resource that contains this object's 
  # graph.
  def resource
   @resource ||= resource_class.new(to_uri)
  end
  
  def parent
    @parent ||= resource.parent
  end

  def parent=(val)
    @parent = val
  end

  ## 
  # @return [String] a uri or slug
  def to_uri
    return id if respond_to? :id and !resource_class.base_uri.nil?
    raise NotImplementedError
  end

  ##
  # Convenience method to return JSON-LD representation
  def as_jsonld
    resource.dump(:jsonld)
  end

  private
    def resource_class
      self.class.resource_class
    end

    def write_attribute(attr_name, value)
      resource.set_value(attr_name, value) if resource_class.properties.has_key? attr_name
      super
    end
    
    def set_relation(name, relation)
      if resource_class.properties.has_key? name then
        documents = relation.is_a?(Enumerable) ? relation : [relation]
        documents.compact.each { |doc| resource.set_value(name, doc.resource.base_uri + doc.to_uri) }
      end

      super
    end
    
  public

    module ClassMethods

      delegate :configure, :properties, to: :resource_class

      def property(*args)
        resource_class.property(*args)
      end

      def resource_class
        @resource_class ||= Class.new(ActiveTriples::Resource)
      end

      def from_uri(uri, *args)
        raise NotImplementedError
      end
    end
end
