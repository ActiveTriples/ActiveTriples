ActiveTriples
==============

[![Build Status](https://travis-ci.org/no-reply/ActiveTriples.png?branch=master)](https://travis-ci.org/no-reply/ActiveTriples)

Modeling RDF graphs in Ruby.

How to Use
-----------

```ruby
class Thing < ActiveTriples::Resource
  configure :type => RDF::OWL.Thing, :base_uri => 'http://example.org/things#'
  property :title, :predicate => RDF::DC.title
  property :description, :predicate => RDF::DC.description
  property :creator, :predicate => RDF::DC.creator, :class_name => 'Person'
end

obj = Thing.new('123')
obj.title = 'Resource'
obj.description = 'A resource in an RDF graph.'

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