source "https://rubygems.org"

gemspec

if RUBY_VERSION =~ /2\.1\..*/
  gem 'activesupport', '< 5.0.0' 
  gem 'rdf-spec',      '< 2.0.3'
end

gem 'pry-byebug' unless ENV["CI"]
