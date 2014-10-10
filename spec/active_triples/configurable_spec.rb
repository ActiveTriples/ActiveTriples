require "spec_helper"
describe ActiveTriples::Configurable do
  before do
    class DummyConfigurable
      extend ActiveTriples::Configurable
    end
  end
  after do
    Object.send(:remove_const, "DummyConfigurable")
  end

  describe '#configure' do
    before do
      DummyConfigurable.configure base_uri: "http://example.org/base", prefix_id: 'b', type: RDF::RDFS.Class, rdf_label: RDF::DC.title
    end

    it 'should set a base uri' do
      expect(DummyConfigurable.base_uri).to eq "http://example.org/base"
    end

    it 'should set a prefix_id' do
      expect(DummyConfigurable.prefix_id).to eq "b"
    end

    it 'should set an rdf_label' do
      expect(DummyConfigurable.rdf_label).to eq RDF::DC.title
    end

    it 'should set a type' do
      expect(DummyConfigurable.type).to eq RDF::RDFS.Class
    end
  end

  describe '#rdf_type' do
    it "should set the type the old way" do
      expect(DummyConfigurable).to receive(:configure).with(type: RDF::RDFS.Class).and_call_original
      expect(Deprecation).to receive(:warn)
      DummyConfigurable.rdf_type(RDF::RDFS.Class)
      expect(DummyConfigurable.type).to eq RDF::RDFS.Class
    end
  end
end
