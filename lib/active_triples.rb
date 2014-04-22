require 'rdf'
require 'active_triples/version'

module ActiveTriples
  autoload :Resource,         'resource'
  autoload :List,             'list'
  autoload :Term,             'term'  
  autoload :Indexing,         'indexing'
  autoload :Configurable,     'configurable'
  autoload :Properties,       'properties'
  autoload :Repositories,     'repositories'
  autoload :NodeConfig,       'node_config'  
  autoload :NestedAttributes, 'nested_attributes'
end
