require "spec_helper"
describe ActiveTriples::Properties do
  before do
    class DummyProperties
      include ActiveTriples::Reflection
      include ActiveTriples::Properties
    end
  end

  after do
    Object.send(:remove_const, "DummyProperties")
  end

  describe '#property' do
    it 'should set a property' do
      DummyProperties.property :title, :predicate => RDF::DC.title
      expect(DummyProperties.reflect_on_property(:title)).to be_kind_of ActiveTriples::NodeConfig
    end

    it 'should set index behaviors' do
      DummyProperties.property :title, :predicate => RDF::DC.title do |index|
        index.as :facetable, :searchable
      end
      expect(DummyProperties.reflect_on_property(:title)[:behaviors]).to eq [:facetable, :searchable]
    end

    it 'should set class name' do
      DummyProperties.property :title, :predicate => RDF::DC.title, :class_name => RDF::Literal
      expect(DummyProperties.reflect_on_property(:title)[:class_name]).to eq RDF::Literal
    end

    it "should constantize string class names" do
      DummyProperties.property :title, :predicate => RDF::DC.title, :class_name => "RDF::Literal"
      expect(DummyProperties.reflect_on_property(:title)[:class_name]).to eq RDF::Literal
    end

    it "should keep strings which it can't constantize as strings" do
      DummyProperties.property :title, :predicate => RDF::DC.title, :class_name => "FakeClassName"
      expect(DummyProperties.reflect_on_property(:title)[:class_name]).to eq "FakeClassName"
    end

    it 'raises error when defining properties that are already methods' do
      DummyProperties.send :define_method, :type, lambda { }
      expect { DummyProperties.property :type, :predicate => RDF::DC.type }.to raise_error ArgumentError
    end

    it 'allows resetting of properties' do
      DummyProperties.property :title, :predicate => RDF::DC.alternative
      DummyProperties.property :title, :predicate => RDF::DC.title
      expect(DummyProperties.reflect_on_property(:title).predicate).to eq RDF::DC.title
    end
  end

  describe '#config_for_term_or_uri' do
    before do
      DummyProperties.property :title, :predicate => RDF::DC.title
    end

    it 'finds property configuration by term symbol' do
      expect(DummyProperties.config_for_term_or_uri(:title)).to eq DummyProperties.properties['title']
    end

    it 'finds property configuration by term string' do
      expect(DummyProperties.config_for_term_or_uri('title')).to eq DummyProperties.properties['title']
    end

    it 'finds property configuration by term URI' do
      expect(DummyProperties.config_for_term_or_uri(RDF::DC.title)).to eq DummyProperties.properties['title']
    end
  end

  describe '#fields' do
    before do
      DummyProperties.property :title, :predicate => RDF::DC.title
      DummyProperties.property :name, :predicate => RDF::FOAF.name
    end

    it 'lists its terms' do
      expect(DummyProperties.fields).to eq [:title, :name]
    end
  end

  context "when using a subclass" do
    before do
      DummyProperties.property :title, :predicate => RDF::DC.title
      class DummySubClass < DummyProperties
        property :source, :predicate => RDF::DC11[:source]
      end
    end

    after do
      Object.send(:remove_const, "DummySubClass")
    end

    it 'should carry properties from superclass' do
      expect(DummySubClass.reflect_on_property(:title)).to be_kind_of ActiveTriples::NodeConfig
      expect(DummySubClass.reflect_on_property(:source)).to be_kind_of ActiveTriples::NodeConfig
    end
  end
end
