module ActiveTriples
  class PropertyBuilder

    attr_reader :name, :options

    def initialize(name, options, &block)
      @name = name
      @options = options
    end

    def self.create_builder(name, options, &block)
      raise ArgumentError, "property names must be a Symbol" unless name.kind_of?(Symbol)

      new(name, options, &block)
    end

    def self.build(model, name, options, &block)
      builder = create_builder name, options, &block
      reflection = builder.build(&block)
      define_accessors model, reflection, options
      reflection
    end

    def self.define_accessors(model, reflection, options={})
      mixin = model.generated_property_methods
      name = reflection.term
      define_readers(mixin, name)
      define_id_reader(model, name) unless options[:cast] == false
      define_writers(mixin, name)
    end

    def self.define_readers(mixin, name)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}(*args)
          get_values(:#{name})
        end
      CODE
    end

    def self.define_id_reader(mixin, name)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_ids(*args)
          get_values(:#{name}, :cast => false)
        end
      CODE
    end

    def self.define_writers(mixin, name)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}=(value)
          set_value(:#{name}, value)
        end
      CODE
    end

    def build(&block)
      NodeConfig.new(name, options[:predicate], options.except(:predicate)) do |config|
        config.with_index(&block) if block_given?
      end
    end
  end
end
