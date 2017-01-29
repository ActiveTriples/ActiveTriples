# frozen_string_literal: true
require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
Bundler.setup

require 'rdf/spec'
require 'rdf/vocab'
require 'webmock/rspec'
require 'active_triples'

require 'pry' unless ENV["CI"]

Dir['./spec/support/**/*.rb'].each { |f| require f }

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.color = true
  config.tty = true

  config.include(RDF::Spec::Matchers)

  # Uncomment the following line to get errors and backtrace for deprecation warnings
  # config.raise_errors_for_deprecations!

  # Use the specified formatter
  config.formatter = :progress
end

def silence_stderr
  @orig_stderr = $stderr
  $stderr = StringIO.new

  yield

  $stderr = @orig_stderr
  @orig_stderr = nil
end

def silence_stdout
  @orig_stdout = $stdout
  $stdout = StringIO.new

  yield

  $stderr = @orig_stdout
  @orig_stdout = nil
end
