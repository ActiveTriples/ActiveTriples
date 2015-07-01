require 'spec_helper'
autoload :DummyPersonReciprocal,   'compatibility_tests/dummy_classes/dummy_person_reciprocal'
autoload :DummyDocumentReciprocal, 'compatibility_tests/dummy_classes/dummy_document_reciprocal'

describe 'reciprocal relationships' do
  before do
    ActiveTriples::Repositories.add_repository :default, RDF::Repository.new
  end

  let (:document_A) do
    d = DummyDocumentReciprocal.new
    d.title = 'Apples Document'
    d
  end

  let (:person_B) do
    p = DummyPersonReciprocal.new
    p.foaf_name = 'Betty'
    p
  end

  let (:person_C) do
    p = DummyPersonReciprocal.new
    p.foaf_name = 'Charles'
    p
  end

  it 'should allow A -> B -> A' do
    document_A.creator = person_B
    expect(document_A.creator).to eq [person_B]
    person_B.publications = document_A
    expect(person_B.publications).to eq [document_A]
  end

  it 'should allow A -> B; A -> C; B -> C' do
    document_A.creator = [person_B,person_C]
    expect(document_A.creator).to eq [person_B,person_C]
    person_B.knows = person_C
    expect(person_B.knows).to eq [person_C]
  end
end

