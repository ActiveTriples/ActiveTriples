0.8.1
-----

  - Reverts changing `Relation`'s delete methods to remove all values until we
  have a clear path forward for those depending on that functionality.

0.8.0
-----
  - Adds RDF.rb interfaces to `RDFSource`, improving interoperability 
  with other `ruby-rdf` packages.
  - Introduces a defined `Persistable` interface and 
  `PersistenceStrategies`.
  - Changes `Relation`'s delete methods to remove all values, instead of
  trying to maintain a predicate -> class pair on the property 
  definitions in some cases. The previous functionality was unclear and
  unreliable.
  - Adds a `Schema` concept, for defining property definitions that are
   portable across `RDFSource` types.


0.7.0
-----

__ATTN: This release withdraws support for Ruby 1.9__

  - Removes `#solrize` which was a badly named holdever from the
  ActiveFedroa days.
  - Fixes a bug on properties defined without a predicate. They are now
  rejected.
  - Disallows setting properties on the `ActiveTriples::Resource` base
  class directly. This kind of property setting is unintended and
  resulted in unexpected behavior.
  - Introduces `ActiveTriples::RDFSource` as a mixin module for which
  forms the basis of `Resource`.
    - Use of this module is now preferred to single inheritance of the
  `Resource` base class.
    - `Resource` will remain indefinitely as the generic model.
  - Renamed `Term` to `Relation`. `Term` is deprecated for removal in
  the next minor release.
  - Allow configuration of multiple `rdf:type`s.
