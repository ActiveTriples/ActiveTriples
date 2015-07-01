require 'spec_helper'

describe 'inherited configuration' do

  subject { DummyTextDocument.new }

  before do
    ActiveTriples::Repositories.add_repository :default, RDF::Repository.new

    class DummyDocument < ActiveTriples::Resource
      configure :type => RDF::URI('http://example.org/Document'),
                :base_uri => 'http://example.org/documents/',
                :repository => :default
      property :title, :predicate => RDF::DC.title
    end

    class DummyTextDocument < DummyDocument
      property :text, :predicate => RDF::DC.description
    end
  end

  after do
    Object.send(:remove_const, "DummyTextDocument")
    Object.send(:remove_const, "DummyDocument")
  end

  it 'should inherit type from parent' do
    expect(subject.type).to eq [RDF::URI('http://example.org/Document')]
  end

  it 'should inherit base_uri from parent' do
    expect(subject.base_uri).to eq 'http://example.org/documents/'
  end

  xit 'should inherit repository from parent' do
    # subject.repository is private
    expect(subject.repository).to eq :default
  end

end

