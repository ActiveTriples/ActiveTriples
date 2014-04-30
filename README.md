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

The core class of ActiveTriples is ActiveTriples::Resource. You can subclass this to create ActiveModel-like classes that represent a node in an RDF graph, and its surrounding statements. Resources implement all the functionality of an RDF::Graph. You can manipulate them by adding or deleting statements, serialize them, and load arbitrary RDF. 


```ruby
class Thing < ActiveTriples::Resource
  configure :type => RDF::OWL.Thing, :base_uri => 'http://example.org/things#'
  property :title, :predicate => RDF::DC.title
  property :description, :predicate => RDF::DC.description
end

obj = Thing.new('123')
obj.title = 'Resource'
obj.description = 'A resource.'
obj.dump :ntriples # => "<http://example.org/things#123> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Thing> .\n<http://example.org/things#123> <http://purl.org/dc/terms/title> \"Resource\" .\n<http://example.org/things#123> <http://purl.org/dc/terms/description> \"A resource.\" .\n"
```
URI and bnode values are built out as Resources when accessed, and a model class can be configured on individual properties.

```ruby
Thing.property :creator, :predicate => RDF::DC.creator, :class_name => 'Person'

class Person < ActiveTriples::Resource
  configure :type => RDF::FOAF.Person, :base_uri => 'http://example.org/people#'
  property :name, :predicate => RDF::FOAF.name
end

obj_2 = Thing.new('2')
obj_2.creator = Person.new
obj_2.creator
# => [#<Person:0x3fbe84ac9234(default)>]

obj_2.creator.first.name = 'Herman Melville'
obj_2.dump :ntriples # => "<http://example.org/things#2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Thing> .\n<http://example.org/things#2> <http://purl.org/dc/terms/creator> _:g70263220218800 .\n_:g70263220218800 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .\n_:g70263220218800 <http://xmlns.com/foaf/0.1/name> \"Herman Melville\" .\n"
```