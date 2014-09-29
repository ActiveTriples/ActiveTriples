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

  private
    def resource_class
      self.class.resource_class
    end

    def update_resource(&block)
      resource_class.properties.each do |name, prop|
        resource.set_value(prop.predicate, self.send(prop.term))
      end

      yield if block_given?
    end

  public

    module ClassMethods

      delegate :configure, :property, :properties, to: :resource_class

      def resource_class
        @resource_class ||= Class.new(ActiveTriples::Resource)
      end

      def from_uri(uri, *args)
        raise NotImplementedError
      end
    end
end
