class DummyPersonReciprocal < ActiveTriples::Resource
  configure :type => RDF::URI('http://example.org/Person'),
            :repository => :default
  property :foaf_name, :predicate => RDF::FOAF.name
  property :publications, :predicate => RDF::FOAF.publications, :class_name => DummyDocumentReciprocal
  property :knows, :predicate => RDF::FOAF.knows, :class_name => DummyPersonReciprocal
end
