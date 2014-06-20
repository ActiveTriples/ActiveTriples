Description
-----------

[![Build Status](https://travis-ci.org/no-reply/ActiveTriples.png?branch=master)](https://travis-ci.org/no-reply/ActiveTriples)

An ActiveModel-like interface for RDF data. Models graphs as Resources with property/attribute configuration, accessors, and other methods to support Linked Data in a Ruby/Rails enviornment.

This library was extracted from work on [ActiveFedora](https://github.com/projecthydra/active_fedora). It is closely related to (and borrows some syntax from) [Spira](https://github.com/ruby-rdf/spira), but does some important things differently.

Installation
------------

Add `gem "active-triples"` to your Gemfile and run `bundle`.

Or install manually with `gem install active-triples`.

Defining Resource Models
------------------------

The core class of ActiveTriples is ActiveTriples::Resource. You can subclass this to create ActiveModel-like classes that represent a node in an RDF graph, and its surrounding statements. Resources implement all the functionality of an RDF::Graph. You can manipulate them by adding or deleting statements, query, serialize, and load arbitrary RDF. 


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

Open Model
-----------

A Resource lets you handle data as a graph, independent of whether it is defined in the model. This is important for working in a Linked Data context, where you will want access to data you may not have known about when your models were written.

```ruby
related = Thing.new

related << RDF::Statement(related, RDF::DC.relation, obj)
related << RDF::Statement(related, RDF::DC.subject, 'ActiveTriples')
	
related.query(:subject => related, :predicate => RDF::DC.relation).each_statement {|s,p,o| puts o}
# => http://example.org/things#123
related.query(:subject => subject, :predicate => RDF::DC.relation).each_statement {|s,p,o| puts o}
# => http://example.org/things#123
```

Any operation you can run against an RDF::Graph works with Resources, too. Or you can use generic setters and getters with URI predicates:

```ruby
related.set_value(RDF::DC.relation, obj) 
related.set_value(RDF::DC.subject, 'ActiveTriples')

related.get_values(RDF::DC.relation) # => [#<Thing:0x3f949c6a2294(default)>]
related.get_values(RDF::DC.subject) # => ["ActiveTriples"]
```

Some convienience methods provide support for handling data from web sources:
  * `fetch` loads data from the Resource's #rdf_subject URI
  * `rdf_label` queries across common (& configured) label fields and returning the best match

```ruby
require 'linkeddata' # to support various serializations

osu = ActiveTriples::Resource.new 'http://dbpedia.org/resource/Oregon_State_University'
osu.fetch

osu.rdf_label => => ["Oregon State University", "Oregon State University", "Université d'État de l'Oregon", "Oregon State University", "Oregon State University", "オレゴン州立大学", "Universidad Estatal de Oregón", "Oregon State University", "俄勒岡州立大學", "Universidade do Estado do Oregon"]
```

Typed Data
-----------

Typed literals are handled natively through Ruby types and [RDF::Literal](https://github.com/ruby-rdf/rdf/tree/develop/lib/rdf/model/literal). There is no need to register a specific type for a property, simply pass the setter the appropriate typed data. See the examples in the RDF::Literal documentation for futher information about supported datatypes.

```ruby
Thing.property :date, :predicate => RDF::DC.date

my_thing = Thing.new
my_thing.date = Date.today

puts my_thing.dump :ntriples
# _:g70072864570340 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Thing> .
# _:g70072864570340 <http://purl.org/dc/terms/date> "2014-06-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .
```

Data is cast back to the appropriate class when it is accessed.

```ruby
my_thing.date
# => [Thu, 19 Jun 2014]
```
   
Note that you can mix types on a single property.

```ruby     
my_thing.date << DateTime.now
my_thing.date << "circa 2014"
my_thing.date
# => [Thu, 19 Jun 2014, Thu, 19 Jun 2014 11:39:21 -0700, "circa 2014"]

puts my_thing.dump :ntriples
# _:g70072864570340 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Thing> .
# _:g70072864570340 <http://purl.org/dc/terms/date> "2014-06-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .
# _:g70072864570340 <http://purl.org/dc/terms/date> "2014-06-19T11:39:21-07:00"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
# _:g70072864570340 <http://purl.org/dc/terms/date> "circa 2014" .
```

Repositories and Persistence
-----------------------------

Contributing
-------------

Please observe the following guidelines:

 - Do your work in a feature branch based on ```master``` and rebase before submitting a pull request.
 - Write tests for your contributions.
 - Document every method you add using YARD annotations. (_Note: Annotations are sparse in the existing codebase, help us fix that!_)
 - Organize your commits into logical units.
 - Don't leave trailing whitespace (i.e. run ```git diff --check``` before committing).
 - Use [well formed](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html) commit messages.

By contributing to ActiveTriples, you agree to dedicate all copyright interest over submitted work to the public domain (see the included ```WAIVER``` and ```LICENSE``` files). For substantial contributions, you may be asked to submit a formal disclaimer of your (and/or your employer's) copyright interest in the software.

License
--------

This is free and unencumbered public domain software. For more information, see http://unlicense.org/ or the accompanying ```LICENSE``` file.
