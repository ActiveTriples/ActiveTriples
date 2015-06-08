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

  it "should be okay if not configured" do
    expect(DummyConfigurable.type).to eq nil
  end

  it "should be okay if configured to nil" do
    DummyConfigurable.configure :type => nil
    expect(DummyConfigurable.type).to eq []
  end

  describe '#configure' do
    before do
      DummyConfigurable.configure base_uri: "http://example.org/base", type: RDF::RDFS.Class, rdf_label: RDF::DC.title
    end

    it 'should set a base uri' do
      expect(DummyConfigurable.base_uri).to eq "http://example.org/base"
    end

    it "should be able to set multiple types" do
      DummyConfigurable.configure type: [RDF::RDFS.Container, RDF::RDFS.ContainerMembershipProperty]
      expect(DummyConfigurable.type).to contain_exactly(RDF::RDFS.Class, RDF::RDFS.Container, RDF::RDFS.ContainerMembershipProperty)
    end

    it 'should set an rdf_label' do
      expect(DummyConfigurable.rdf_label).to eq RDF::DC.title
    end

    it 'should set a type' do
      expect(DummyConfigurable.type).to eq [RDF::RDFS.Class]
    end

    it "should be able to set multiple types" do
      DummyConfigurable.configure type: RDF::RDFS.Container
      expect(DummyConfigurable.type).to eq [RDF::RDFS.Class, RDF::RDFS.Container]
    end
  end
end
