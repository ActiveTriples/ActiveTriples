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
    
  public

    module ClassMethods

      delegate :configure, :properties, to: :resource_class

      def property(*args)
        prop = args.first
        define_method prop.to_s do 
          resource.get_values(prop)
        end
        define_method "#{prop.to_s}=" do |*args|
          resource.set_value(prop, *args)
        end
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
