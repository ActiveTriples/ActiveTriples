require 'spec_helper'

describe ActiveTriples::Resource do
  before do
    class DummyLicense < ActiveTriples::Resource
      property :title, :predicate => RDF::DC.title
    end

    class DummyResource < ActiveTriples::Resource
      configure :type => RDF::URI('http://example.org/SomeClass'),
                :repository => :default

      property :license, :predicate => RDF::DC.license, :class_name => DummyLicense
      property :title, :predicate => RDF::DC.title
    end
  end
  after do
    Object.send(:remove_const, "DummyResource") if Object
    Object.send(:remove_const, "DummyLicense") if Object
  end

  subject { DummyResource.new }

  describe '#persist!' do
    it 'followed by resume should produce equal objects' do
      ActiveTriples::Repositories.add_repository :default, RDF::Repository.new
      dr = DummyResource.new('http://exmple.org/dr')
      dr.persist!
      drr = DummyResource.new('http://exmple.org/dr')
      expect(dr).to eq drr
    end
  end

end
