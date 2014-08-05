require 'rdf'
require 'active_triples/version'

module ActiveTriples
  autoload :Resource,         'active_triples/resource'
  autoload :List,             'active_triples/list'
  autoload :Term,             'active_triples/term'  
  autoload :Indexing,         'active_triples/indexing'
  autoload :Configurable,     'active_triples/configurable'
  autoload :Properties,       'active_triples/properties'
  autoload :Repositories,     'active_triples/repositories'
  autoload :NodeConfig,       'active_triples/node_config'  
  autoload :NestedAttributes, 'active_triples/nested_attributes'
  autoload :Identifiable,     'active_triples/identifiable'

  def self.class_from_string(class_name, container_class=Kernel)
    container_class = container_class.name if container_class.is_a? Module
    container_parts = container_class.split('::')
    (container_parts + class_name.split('::')).flatten.inject(Kernel) do |mod, class_name|
      if mod == Kernel
        Object.const_get(class_name)
      elsif mod.const_defined? class_name.to_sym
        mod.const_get(class_name)
      else
        container_parts.pop
        class_from_string(class_name, container_parts.join('::'))
      end
    end
  end
end
