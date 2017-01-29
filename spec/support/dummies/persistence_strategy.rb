require 'active_triples/persistence_strategies/persistence_strategy'

class FakePersistenceStrategy
  include ActiveTriples::PersistenceStrategy
  
  def initialize(source); end
  
  def persist!
    true
  end
end
