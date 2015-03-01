require 'rdf'
require 'active_triples/version'
require 'active_support'

module ActiveTriples
  extend ActiveSupport::Autoload
  eager_autoload do
    autoload :RDFSource
    autoload :Resource
    autoload :List
    autoload :Relation
    autoload :Configurable
    autoload :Persistable
    autoload :Properties
    autoload :PropertyBuilder
    autoload :Reflection
    autoload :Repositories
    autoload :NodeConfig
    autoload :NestedAttributes
    autoload :Identifiable
    autoload :ParentStrategy, 'active_triples/persistence_strategies/parent_strategy'
    autoload :RepositoryStrategy, 'active_triples/persistence_strategies/repository_strategy'

    # deprecated class
    autoload :Term, 'active_triples/relation'
  end

  # Raised when a declared repository doesn't have a definition
  class RepositoryNotFoundError < StandardError
  end

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

  def self.ActiveTripels
    puts <<-eos

        ###########
        ******o****
         **o******
          *******
           \\***/
            | |
            ( )
            / \\
        ,---------.

eos
"Yum"
  end

end
