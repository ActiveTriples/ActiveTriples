
Getting Started with ActiveTriples
==================================

`ActiveTriples` is Object-Graph-Model engine for managing [RDF](http://www.w3.org/RDF/) 
data as ActiveModel compliant Ruby objects.

This guide attempts to give a full overview of the features and capabilities of 
`ActiveTriples`. If you are already familiar with RDF and looking for a brief 
overview see the [README](README.md).

Installing
------------

To install, add `gem "active-triples"` to your Gemfile and run `bundle`.

Alternatively, you may install manually with `gem install active-triples`.

Understanding RDF
-----------------

RDF is an abstract, graph-based model for data on the web. In addition to a simple 
data model, it has:

  - An extensible, URI-based vocabulary system
  - A flexible formal semantics and with entailment support
  - An "Open World" of distributed "linked data"

RDF expresses data as atomic statements or __triples__ in a directed __graph__

[RDF Concepts](http://www.w3.org/TR/2004/REC-rdf-concepts-20040210) is a
 good place to start digging deeper.

### The RDF.rb Object Model


Defining Models
----------------


### `RDFSource`
