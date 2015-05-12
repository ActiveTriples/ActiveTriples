module ActiveTriples
  class Configuration
    def initialize(options={})
      @inner_hash = Hash[options.to_a]
    end

    def merge(options)
      new_config = Configuration.new(options).to_h
      current_config = to_h
      new_config[:type] = Array(current_config[:type]) | Array(new_config[:type])
      Configuration.new(current_config.merge(new_config))
    end

    def [](value)
      to_h[value]
    end

    def to_h
      @inner_hash.slice(*valid_config_options)
    end

    private

    def valid_config_options
      [:base_uri, :rdf_label, :type, :repository]
    end
  end
end
