source "https://rubygems.org"

gemspec

version = Gem::Version.new(RUBY_VERSION)

if (version <= Gem::Version.new('2.2.4')) &&
   (version >= Gem::Version.new('2.0.0'))
  gem 'ruby_dep', '< 1.4.0'
end

gem 'listen',        '< 3.1'   if version <= Gem::Version.new('2.2.3')
gem 'activesupport', '< 5'     if version <= Gem::Version.new('2.2.2')

if version <= Gem::Version.new('2.1.0')
  gem 'deprecation',   '< 0.3.0'
  gem 'nokogiri',      '< 1.7'
end

if version <= Gem::Version.new('2.0.0')
  gem 'public_suffix', '< 1.5'
  gem 'json-ld',       '< 1.8'
  gem 'linkeddata',    '<= 1.1.11'
  gem 'webmock',       '< 2.3'
end
