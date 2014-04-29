require 'bundler/setup'
Bundler.setup

require 'active_triples'

Dir['./spec/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  config.color_enabled = true
  config.tty = true

  # Use the specified formatter
  config.formatter = :progress
end
