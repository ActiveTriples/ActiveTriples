require 'spec_helper'

describe 'persist blank nodes' do
  before do
    ActiveTriples::Repositories.add_repository :default, RDF::Repository.new

    class DummyLicense < ActiveTriples::Resource
      configure :type => RDF::URI('http://example.org/SomeClass'),
                :repository => :default,
                :base_uri => 'http://example.org'
      property :title, :predicate => RDF::DC.title
    end

    class DummyResource < ActiveTriples::Resource
      configure :type => RDF::URI('http://example.org/SomeClass'),
                :repository => :default,
                :base_uri => 'http://example.org'
      property :license, :predicate => RDF::DC.license, :class_name => DummyLicense
      property :title, :predicate => RDF::DC.title
    end
  end
  after do
    Object.send(:remove_const, "DummyResource") if Object
    Object.send(:remove_const, "DummyLicense") if Object
  end

  describe '#persist!' do
    xit 'should persist non-blank node after persisting non-blank node' do
      dr = DummyResource.new('dr2')
      dr.persist!
      expect(dr).to be_persisted

      dl = DummyLicense.new('dl2')    # create license as blank node
      dl.persist!
      expect(dl).to be_persisted
    end

    it 'should persist blank node after persisting non-blank node' do
      dr = DummyResource.new('dr1')
      dr.persist!
      expect(dr).to be_persisted

      dl = DummyLicense.new    # create license as blank node
      dl.persist!
      expect(dl).to be_persisted
    end

    xit 'should persist blank node' do
      dl = DummyLicense.new    # create license as blank node
      dl.persist!
      expect(dl).to be_persisted
    end
  end

end
