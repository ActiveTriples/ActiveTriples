class DummyDocumentReciprocal < ActiveTriples::Resource
  configure :type => RDF::URI('http://example.org/Document'),
            :repository => :default
  property :title, :predicate => RDF::DC.title
  property :creator, :predicate => RDF::DC.creator, :class_name => DummyPersonReciprocal
end
