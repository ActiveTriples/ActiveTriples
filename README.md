ActiveTriples
==============

[![Build Status](https://travis-ci.org/no-reply/ActiveTriples.png?branch=master)](https://travis-ci.org/no-reply/ActiveTriples)

An ActiveModel-like interface for RDF data. Models graphs as Resources with property/attribute configuration, accessors, and other methods to support Linked Data in a Ruby/Rails enviornment.

Installation
------------

Add `gem "active-triples"` to your Gemfile and run `bundle`.

Or install manually with `gem install active-triples`.

How to Use
-----------

The core class of ActiveTriples is ActiveTriples::Resource. You can subclass this to create ActiveModel-like classes that represent a node in an RDF graph, and its surrounding statements.

```ruby
class Thing < ActiveTriples::Resource
  configure :type => RDF::OWL.Thing, :base_uri => 'http://example.org/things#'
  property :title, :predicate => RDF::DC.title
  property :description, :predicate => RDF::DC.description
end

obj = Thing.new('123')
obj.title = 'Resource'
obj.description = 'A resource.'
```

Resources implement all the functionality of an RDF::Graph, so you can manipulate them by adding or deleting statements, serialize their data, and even load arbitrary data from a file.

```ruby
obj.dump :ntriples # => "<http://example.org/things#123> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Thing> .\n<http://example.org/things#123> <http://purl.org/dc/terms/title> \"Resource\" .\n<http://example.org/things#123> <http://purl.org/dc/terms/description> \"A resource.\" .\n"

obj << RDF::Statement(obj.rdf_subject, RDF::DC.description, RDF::Literal('another description', :lang => 'en'))
obj << RDF::Statement(obj.rdf_subject, RDF::URI('http://example.org/my_predicate'), RDF::URI('http://example.org/my_value'))
obj.dump :ntriples # => "<http://example.org/things#123> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Thing> .\n<http://example.org/things#123> <http://purl.org/dc/terms/title> \"Resource\" .\n<http://example.org/things#123> <http://purl.org/dc/terms/description> \"A resource.\" .\n<http://example.org/things#123> <http://purl.org/dc/terms/description> \"another description\" .\n<http://example.org/things#123> <http://example.org/my_predicate> <http://example.org/my_value> .\n"

obj.get_values(RDF::URI('http://example.org/my_predicate')) # => [#<ActiveTriples::Resource:0x3fe76e3acec0(default)>]
```

```ruby
Thing.property :creator, :predicate => RDF::DC.creator, :class_name => 'Person'

obj.dump :ntriples
# => "<http://example.org/things#123> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Thing> .\n<http://example.org/things#123> <http://purl.org/dc/terms/title> \"Resource\" .\n<http://example.org/things#123> <http://purl.org/dc/terms/description> \"A resource in an RDF graph.\" .\n"

class Person < ActiveTriples::Resource
  configure :type => RDF::FOAF.Person, :base_uri => 'http://example.org/people#'
  property :name, :predicate => RDF::FOAF.name
end

obj.creator = Person.new
obj.creator
# => [#<Person:0x3fbe84ac9234(default)>]

obj.creator.first.name = 'Herman Melville'
obj.dump :ntriples
# => "<http://example.org/things#123> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Thing> .\n<http://example.org/things#123> <http://purl.org/dc/terms/title> \"Resource\" .\n<http://example.org/things#123> <http://purl.org/dc/terms/description> \"A resource in an RDF graph.\" .\n<http://example.org/things#123> <http://purl.org/dc/terms/creator> _:g70087502237940 .\n_:g70087502237940 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .\n"
```