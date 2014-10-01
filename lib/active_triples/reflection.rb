require 'active_support/core_ext/class'

module ActiveTriples
  module Reflection
    extend ActiveSupport::Concern

    included do
      class_attribute :_active_triples_config
      self._active_triples_config = {}
    end

    def self.add_reflection(model, name, reflection)
      model._active_triples_config = model._active_triples_config.merge(name.to_s => reflection)
    end

    module ClassMethods
      def reflect_on_property(term)
        _active_triples_config[term.to_s]
      end

      def properties
        _active_triples_config
      end

      def properties=(val)
        self._active_triples_config = val
      end
    end
  end
end
