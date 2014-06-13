require 'spec_helper'
require 'pragmatic_context'

describe 'PragmaticContext integration' do
  before do
    class DummyLicense < ActiveTriples::Resource
      include PragmaticContext::Contextualizable
      property :title, :predicate => RDF::DC.title

      contextualize :title, :as => RDF::DC.title.to_s
    end

    class DummyResource < ActiveTriples::Resource
      include PragmaticContext::Contextualizable

      configure :type => RDF::URI('http://example.org/SomeClass')
      property :license, :predicate => RDF::DC.license, :class_name => DummyLicense
      property :title, :predicate => RDF::DC.title

      contextualize :title, :as => RDF::DC.title.to_s
      contextualize :license, :as => RDF::DC.license.to_s
    end

    license.title = 'cc'
    subject.title = 'my resource'
    subject.license = license
    subject.license << RDF::Literal('Creative Commons')
  end

  after do
    Object.send(:remove_const, "DummyResource") if Object
    Object.send(:remove_const, "DummyLicense") if Object
  end

  subject { DummyResource.new('http://example.org/test') }
  let(:license) { DummyLicense.new }

  xit 'should output a valid jsonld representation of itself' do
    g = RDF::Graph.new << JSON::LD::API.toRdf(subject.as_jsonld)
    expect(subject == g).to be true
  end

  it 'should have contexts' do
    expect(subject.as_jsonld['@context'].keys).to eq ["license", "title"]
  end
  
  it 'should use context with dump' do
    context = JSON.parse(subject.dump :jsonld)['@context']
    subject.class.properties.keys.each do |prop|
      expect(context).to include prop
    end
  end
end
