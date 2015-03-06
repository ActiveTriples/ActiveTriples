require 'spec_helper'

describe ActiveTriples::Resource do
  it_behaves_like 'an ActiveModel'
  before do
    class DummyLicense < ActiveTriples::Resource
      property :title, :predicate => RDF::DC.title
    end

    class DummyResource < ActiveTriples::Resource
      configure :type => RDF::URI('http://example.org/SomeClass')
      property :license, :predicate => RDF::DC.license, :class_name => DummyLicense
      property :title, :predicate => RDF::DC.title
    end
  end
  after do
    Object.send(:remove_const, "DummyResource") if Object
    Object.send(:remove_const, "DummyLicense") if Object
  end

  subject { DummyResource.new }

  describe '#property' do
    it 'raises error when set directly on Resource' do
      expect { ActiveTriples::Resource.property :blah, :predicate => RDF::DC.title }.to raise_error
    end
  end

  describe 'rdf_subject' do
    it "should be a blank node if we haven't set it" do
      expect(subject.rdf_subject.node?).to be true
    end

    it "should be settable" do
      subject.set_subject! RDF::URI('http://example.org/moomin')
      expect(subject.rdf_subject).to eq RDF::URI('http://example.org/moomin')
    end

    it "should raise an error when setting to an invalid uri" do
      expect{ subject.set_subject!('not_a_uri') }.to raise_error "could not make a valid RDF::URI from not_a_uri"
    end

    describe 'when changing subject' do
      before do
        subject << RDF::Statement.new(subject.rdf_subject, RDF::DC.title, RDF::Literal('Comet in Moominland'))
        subject << RDF::Statement.new(RDF::URI('http://example.org/moomin_comics'), RDF::DC.isPartOf, subject.rdf_subject)
        subject << RDF::Statement.new(RDF::URI('http://example.org/moomin_comics'), RDF::DC.relation, 'http://example.org/moomin_land')
        subject.set_subject! RDF::URI('http://example.org/moomin')
      end

      it 'should update graph subjects' do
        expect(subject.has_statement?(RDF::Statement.new(subject.rdf_subject, RDF::DC.title, RDF::Literal('Comet in Moominland')))).to be true
      end

      it 'should update graph objects' do
        expect(subject.has_statement?(RDF::Statement.new(RDF::URI('http://example.org/moomin_comics'), RDF::DC.isPartOf, subject.rdf_subject))).to be true
      end

      it 'should leave other uris alone' do
        expect(subject.has_statement?(RDF::Statement.new(RDF::URI('http://example.org/moomin_comics'), RDF::DC.relation, 'http://example.org/moomin_land'))).to be true
      end
    end

    describe 'with URI subject' do
      before do
        subject.set_subject! RDF::URI('http://example.org/moomin')
      end

      it 'should not be settable' do
        expect{ subject.set_subject! RDF::URI('http://example.org/moomin2') }.to raise_error
      end
    end

    context 'with null relative URI subject' do
      before do
        subject.set_subject! RDF::URI(nil)
      end

      it 'should have a subject of <>' do
        expect(subject.rdf_subject).to eq RDF::URI(nil)
      end

      it 'should be settable' do
        subject.set_subject! RDF::URI('http://example.org/moomin')
        expect(subject.rdf_subject).to eq RDF::URI('http://example.org/moomin')
      end
    end
  end

  describe "#persisted?" do
    context 'with a repository' do
      before do
        repository = RDF::Repository.new
        allow(subject).to receive(:repository).and_return(repository)
      end

      context "when the object is new" do
        it "should return false" do
          expect(subject).not_to be_persisted
        end
      end

      context "when it is saved" do
        before do
          subject.title = "bla"
          subject.persist!
        end

        it "should return true" do
          expect(subject).to be_persisted
        end

        context "and then modified" do
          before do
            subject.title = "newbla"
          end

          it "should return true" do
            expect(subject).to be_persisted
          end
        end
        context "and then reloaded" do
          before do
            subject.reload
          end

          it "should reset the title" do
            expect(subject.title).to eq ["bla"]
          end

          it "should be persisted" do
            expect(subject).to be_persisted
          end
        end
      end
    end
  end

  describe "#persist!" do
    context "when the repository is set" do
      context "and the item is not a blank node" do

        subject {DummyResource.new("info:fedora/example:pid")}
        let(:result) { subject.persist! }

        before do
          @repo = RDF::Repository.new
          allow(subject.class).to receive(:repository).and_return(nil)
          allow(subject).to receive(:repository).and_return(@repo)
          subject.title = "bla"
          result
        end

        it "should return true" do
          expect(result).to eq true
        end

        it "should persist to the repository" do
          expect(@repo.statements.first).to eq subject.statements.first
        end

        it "should delete from the repository" do
          subject.reload
          expect(subject.title).to eq ["bla"]
          subject.title = []
          expect(subject.title).to eq []
          subject.persist!
          subject.reload
          expect(subject.title).to eq []
          expect(@repo.statements.to_a.length).to eq 1 # Only the type statement
        end

        context "and validations are checked" do
          let(:result) { subject.persist!(:validate => true) }
          context "and it's valid" do
            it "should return true" do
              expect(result).to eq true
            end
          end
          context "and it's invalid" do
            subject do
              a = DummyResource.new("info:fedora/example:pid")
              allow(a).to receive(:valid?).and_return(false)
              a
            end
            it "should return false" do
              expect(result).to eq false
            end
            it "should not be persisted" do
              expect(subject).not_to be_persisted
            end
          end
        end
      end
    end
  end

  describe "#id_persisted?" do

    subject {DummyResourceWithBaseURI.new('1')}

    before do
      class DummyResourceWithBaseURI < ActiveTriples::Resource
        configure :base_uri => "http://example.org",
                  :type => RDF::URI("http://example.org/SomeClass"),
                  :repository => :default
      end
      ActiveTriples::Repositories.add_repository :default, RDF::Repository.new
      subject.persist!
    end
    after do
      Object.send(:remove_const, "DummyResourceWithBaseURI") if Object
      ActiveTriples::Repositories.clear_repositories!
    end

    context "when ID is a string" do
      it "should be false if ID does not exist" do
        expect(DummyResourceWithBaseURI.id_persisted?('2')).to be_falsey
      end

      it "should be true if ID exists" do
        expect(DummyResourceWithBaseURI.id_persisted?('1')).to be_truthy
      end
    end

    context "when ID is numeric" do
      it "should be false if ID does not exist" do
        expect(DummyResourceWithBaseURI.id_persisted?(2)).to be_falsey
      end

      it "should be true if ID exists" do
        expect(DummyResourceWithBaseURI.id_persisted?(1)).to be_truthy
      end
    end

    context "when object with ID in use is not persisted" do
      it "should be false" do
        DummyResourceWithBaseURI.new('3')
        expect(DummyResourceWithBaseURI.id_persisted?(3)).to be_falsey
      end
    end
  end

  describe "#uri_persisted?" do

    subject {DummyResourceWithBaseURI.new('11')}

    before do
      class DummyResourceWithBaseURI < ActiveTriples::Resource
        configure :base_uri => "http://example.org",
                  :type => RDF::URI("http://example.org/SomeClass"),
                  :repository => :default
      end
      ActiveTriples::Repositories.add_repository :default, RDF::Repository.new
      subject.persist!
    end
    after do
      Object.send(:remove_const, "DummyResourceWithBaseURI") if Object
      ActiveTriples::Repositories.clear_repositories!
    end

    context "when URI is a http string" do
      it "should be false if URI does not exist" do
        expect(DummyResourceWithBaseURI.uri_persisted?("http://example.org/22")).to be_falsey
      end

      it "should be true if URI does exist" do
        expect(DummyResourceWithBaseURI.uri_persisted?("http://example.org/11")).to be_truthy
      end
    end

    context "when URI is a RDF::URI" do
      it "should be false if URI does not exist" do
        expect(DummyResourceWithBaseURI.uri_persisted?(RDF::URI("http://example.org/22"))).to be_falsey
      end

      it "should be true if URI does exist" do
        expect(DummyResourceWithBaseURI.uri_persisted?(RDF::URI("http://example.org/11"))).to be_truthy
      end
    end

    context "when object with URI is not persisted" do
      it "should be false" do
        DummyResourceWithBaseURI.new('13')
        expect(DummyResourceWithBaseURI.uri_persisted?("http://example.org/13")).to be_falsey
      end
    end
  end

  describe '#repository' do
    subject { DummyLicense.new('http://example.org/cc')}

    it "should warn when the repo doesn't exist" do
      allow(DummyLicense).to receive(:repository).and_return('repo2')
      expect { subject.title }.to raise_error ActiveTriples::RepositoryNotFoundError, 'The class DummyLicense expects a repository called repo2, but none was declared'
    end
  end

  describe '#destroy!' do
    before do
      subject.title = 'Creative Commons'
      subject << RDF::Statement(RDF::DC.LicenseDocument, RDF::DC.title, 'LICENSE')
    end

    subject { DummyLicense.new('http://example.org/cc')}

    it 'should return true' do
      expect(subject.destroy!).to be true
      expect(subject.destroy).to be true
    end

    it 'should delete the graph' do
      subject.destroy
      expect(subject).to be_empty
    end

    context 'with a parent' do
      before do
        parent.license = subject
      end

      let(:parent) do
        DummyResource.new('http://example.org/moomi')
      end

      it 'should empty the graph and remove it from the parent' do
        subject.destroy
        expect(parent.license).to be_empty
      end

      it 'should remove its whole graph from the parent' do
        subject.destroy
        subject.each_statement do |s|
          expect(parent.statements).not_to include s
        end
      end
    end
  end

  describe 'class_name' do
    it 'should raise an error when not a class or string' do
      DummyResource.property :relation, :predicate => RDF::DC.relation, :class_name => RDF::URI('http://example.org')
      d = DummyResource.new
      d.relation = RDF::DC.type
      expect { d.relation.first }.to raise_error "class_name for relation is a RDF::URI; must be a class"
    end

    it 'should return nil when none is given' do
      expect(DummyResource.reflect_on_property('title')[:class_name]).to be_nil
    end

  end

  context 'property configuration' do
    it 'preserves previous #properties[] API but prefers #reflect_on_property' do
      expect(DummyResource.reflect_on_property('title')).to eq(DummyResource.properties.fetch('title'))
    end

    it 'uses hash access on #properties to retrieve the configuration' do
      expect(DummyResource.properties['title']).to be_a(ActiveTriples::NodeConfig)
    end

    it 'stores the properties configuration as a hash' do
      expect(DummyResource.properties).to be_a(Hash)
    end

    it "uses reflection to retrieve a property's configuration" do
      expect(DummyResource.reflect_on_property('title')).to be_a(ActiveTriples::NodeConfig)
    end
  end

  describe 'attributes' do
    before do
      subject.license = license
      subject.title = 'moomi'
    end

    let(:license) { DummyLicense.new('http://example.org/license') }

    it 'should return an attributes hash' do
      expect(subject.attributes).to be_a Hash
    end

    it 'should contain data' do
      expect(subject.attributes['title']).to eq ['moomi']
    end

    it 'should contain child objects' do
      expect(subject.attributes['license']).to eq [license]
    end

    context 'with unmodeled data' do
      before do
        subject << RDF::Statement(subject.rdf_subject, RDF::DC.contributor, 'Tove Jansson')
        subject << RDF::Statement(subject.rdf_subject, RDF::DC.relation, RDF::URI('http://example.org/moomi'))
        node = RDF::Node.new
        subject << RDF::Statement(RDF::URI('http://example.org/moomi'), RDF::DC.relation, node)
        subject << RDF::Statement(node, RDF::DC.title, 'bnode')
      end

      it 'should include data with URIs as attribute names' do
        expect(subject.attributes[RDF::DC.contributor.to_s]).to eq ['Tove Jansson']
      end

      it 'should return generic Resources' do
        expect(subject.attributes[RDF::DC.relation.to_s].first).to be_a ActiveTriples::Resource
      end

      it 'should build deep data for Resources' do
        expect(subject.attributes[RDF::DC.relation.to_s].first.get_values(RDF::DC.relation).
               first.get_values(RDF::DC.title)).to eq ['bnode']
      end

      it 'should include deep data in serializable_hash' do
        expect(subject.serializable_hash[RDF::DC.relation.to_s].first.get_values(RDF::DC.relation).
               first.get_values(RDF::DC.title)).to eq ['bnode']
      end
    end

    describe 'attribute_serialization' do
      describe '#to_json' do
        it 'should return a string with correct objects' do
          json_hash = JSON.parse(subject.to_json)
          expect(json_hash['license'].first['id']).to eq license.rdf_subject.to_s
        end
      end
    end
  end

  describe 'property methods' do
    it 'should set and get properties' do
      subject.title = 'Comet in Moominland'
      expect(subject.title).to eq ['Comet in Moominland']
    end
  end

  describe 'array setters' do
    before do
      DummyResource.property :aggregates, :predicate => RDF::DC.relation
    end

    it "should be empty array if we haven't set it" do
      expect(subject.aggregates).to match_array([])
    end

    context "when set to a URI" do
      let(:aggregates_uri) { RDF::URI("http://example.org/b1") }
      before do
        subject.aggregates = aggregates_uri
      end
      it "produce an ActiveTriple::Resource" do
        expect(subject.aggregates.first).to be_a ActiveTriples::Resource
      end
      it "should have an ID accessor" do
        expect(subject.aggregates_ids).to eq [aggregates_uri]
      end
    end

    it "should be settable" do
      subject.aggregates = RDF::URI("http://example.org/b1")
      expect(subject.aggregates.first.rdf_subject).to eq RDF::URI("http://example.org/b1")
      ['id']
    end

    context 'with values' do
      let(:bib1) { RDF::URI("http://example.org/b1") }
      let(:bib2) { RDF::URI("http://example.org/b2") }
      let(:bib3) { RDF::URI("http://example.org/b3") }

      before do
        subject.aggregates = bib1
        subject.aggregates << bib2
        subject.aggregates << bib3
      end

      it 'raises error when trying to set nil value' do
        expect { subject.aggregates[1] = nil }.to raise_error /value must be an RDF URI, Node, Literal, or a valid datatype/
      end

      it "should be changeable for multiple values" do
        new_bib1 = RDF::URI("http://example.org/b1_NEW")
        new_bib3 = RDF::URI("http://example.org/b3_NEW")

        aggregates = subject.aggregates.dup
        aggregates[0] = new_bib1
        aggregates[2] = new_bib3
        subject.aggregates = aggregates

        expect(subject.aggregates[0].rdf_subject).to eq new_bib1
        expect(subject.aggregates[1].rdf_subject).to eq bib2
        expect(subject.aggregates[2].rdf_subject).to eq new_bib3
      end

      it "raises an error for out of bounds index" do
        expect { subject.aggregates[4] = 'blah' }.to raise_error IndexError
      end
    end
  end

  describe 'child nodes' do
    it 'should return an object of the correct class when the value is a URI' do
      subject.license = DummyLicense.new('http://example.org/license')
      expect(subject.license.first).to be_kind_of DummyLicense
    end

    it 'should return an object with the correct URI when the value is a URI ' do
      subject.license = DummyLicense.new('http://example.org/license')
      expect(subject.license.first.rdf_subject).to eq RDF::URI("http://example.org/license")
    end

    it 'should return an object of the correct class when the value is a bnode' do
      subject.license = DummyLicense.new
      expect(subject.license.first).to be_kind_of DummyLicense
    end
  end

  describe '#set_value' do
    it 'should set a value in the graph' do
      subject.set_value(RDF::DC.title, 'Comet in Moominland')
      subject.query(:subject => subject.rdf_subject, :predicate => RDF::DC.title).each_statement do |s|
        expect(s.object.to_s).to eq 'Comet in Moominland'
      end
    end

    context "when given a URI" do
      before do
        subject.set_value(RDF::DC.title, RDF::URI("http://opaquenamespace.org/jokes/1"))
      end
      it "should return a resource" do
        expect(subject.title.first).to be_kind_of(ActiveTriples::RDFSource)
      end
      context "and it's configured to not cast" do
        before do
          subject.class.property :title, predicate: RDF::DC.title, cast: false
        end
        it "should return a URI" do
          expect(subject.title.first).to be_kind_of(RDF::URI)
        end
      end
    end

    it "safely handles terms passed in" do
      vals = subject.get_values('license')
      vals << "foo"
      subject.set_value('license',vals)
      expect(subject.get_values('license')).to eq ["foo"]
    end

    it "safely handles terms passed in with pre-existing values" do
      subject.license = "foo"
      vals = subject.get_values('license')
      vals << "bar"
      subject.set_value('license',vals)
      expect(subject.get_values('license')).to eq ["foo","bar"]
    end

    it 'should set a value in the when given a registered property symbol' do
      subject.set_value(:title, 'Comet in Moominland')
      expect(subject.title).to eq ['Comet in Moominland']
    end

    it "raise an error if the value is not a URI, Node, Literal, RdfResource, or string" do
      expect{subject.set_value(RDF::DC.title, Object.new)}.to raise_error
    end

    it "should be able to accept a subject" do
      expect{subject.set_value(RDF::URI("http://opaquenamespace.org/jokes"), RDF::DC.title, 'Comet in Moominland')}.not_to raise_error
      expect(subject.query(:subject => RDF::URI("http://opaquenamespace.org/jokes"), :predicate => RDF::DC.title).statements.to_a.length).to eq 1
    end
  end

  describe '#[]=' do
    it 'should set a value in the graph' do
      subject[RDF::DC.title] = 'Comet in Moominland'
      subject.query(:subject => subject.rdf_subject, :predicate => RDF::DC.title).each_statement do |s|
        expect(s.object.to_s).to eq 'Comet in Moominland'
      end
    end

    it 'should set a value in the when given a registered property symbol' do
      subject[:title] = 'Comet in Moominland'
      expect(subject.title).to eq ['Comet in Moominland']
    end

    it "raise an error if the value is not a URI, Node, Literal, RdfResource, or string" do
      expect { subject[RDF::DC.title] = Object.new }.to raise_error
    end
  end

  describe '#get_values' do
    before do
      subject.title = ['Comet in Moominland', "Finn Family Moomintroll"]
    end

    it 'should return values for a predicate uri' do
      expect(subject.get_values(RDF::DC.title)).to eq ['Comet in Moominland', 'Finn Family Moomintroll']
    end

    it 'should return values for a registered predicate symbol' do
      expect(subject.get_values(:title)).to eq ['Comet in Moominland', 'Finn Family Moomintroll']
    end

    it "should return values for other subjects if asked" do
      expect(subject.get_values(RDF::URI("http://opaquenamespace.org/jokes"),:title)).to eq []
      subject.set_value(RDF::URI("http://opaquenamespace.org/jokes"), RDF::DC.title, 'Comet in Moominland')
      expect(subject.get_values(RDF::URI("http://opaquenamespace.org/jokes"),:title)).to eq ["Comet in Moominland"]
    end

    context "literals are set" do
      let(:literal1) { RDF::Literal.new("test", :language => :en) }
      let(:literal2) { RDF::Literal.new("test", :language => :fr) }
      before do
        subject.set_value(RDF::DC.title, [literal1, literal2])
      end
      context "and literals are not requested" do
        it "should return a string" do
          # Should this de-duplicate?
          expect(subject.get_values(RDF::DC.title)).to eq ["test", "test"]
        end
      end
      context "and literals are requested" do
        it "should return literals" do
          expect(subject.get_values(RDF::DC.title, :literal => true)).to eq [literal1, literal2]
        end
      end
    end

  end

  describe '#[]' do
    before do
      subject.title = ['Comet in Moominland', "Finn Family Moomintroll"]
    end

    it 'should return values for a predicate uri' do
      expect(subject[RDF::DC.title]).to eq ['Comet in Moominland', 'Finn Family Moomintroll']
    end

    it 'should return values for a registered predicate symbol' do
      expect(subject[:title]).to eq ['Comet in Moominland', 'Finn Family Moomintroll']
    end

    it "should return values for other subjects if asked" do
      expect(subject.get_values(RDF::URI("http://opaquenamespace.org/jokes"),:title)).to eq []
      subject.set_value(RDF::URI("http://opaquenamespace.org/jokes"), RDF::DC.title, 'Comet in Moominland')
      expect(subject.get_values(RDF::URI("http://opaquenamespace.org/jokes"),:title)).to eq ["Comet in Moominland"]
    end
  end

  describe '#type' do
    it 'should return the type configured on the parent class' do
      expect(subject.type).to eq DummyResource.type
    end

    it 'should set the type' do
      subject.type = RDF::URI('http://example.org/AnotherClass')
      expect(subject.type).to eq [RDF::URI('http://example.org/AnotherClass')]
    end

    it 'should be the type in the graph' do
      subject.query(:subject => subject.rdf_subject, :predicate => RDF.type).statements do |s|
        expect(s.object).to eq RDF::URI('http://example.org/AnotherClass')
      end
    end
  end

  describe '#rdf_label' do
    it 'should return an array of label values' do
      expect(subject.rdf_label).to be_kind_of Array
    end

    it 'should return the default label values' do
      subject.title = 'Comet in Moominland'
      expect(subject.rdf_label).to eq ['Comet in Moominland']
    end

    it 'should prioritize configured label values' do
      custom_label = RDF::URI('http://example.org/custom_label')
      subject.class.configure :rdf_label => custom_label
      subject << RDF::Statement(subject.rdf_subject, custom_label, RDF::Literal('New Label'))
      subject.title = 'Comet in Moominland'
      expect(subject.rdf_label).to eq ['New Label']
    end
  end

  describe 'editing the graph' do
    it 'should write properties when statements are added' do
      subject << RDF::Statement.new(subject.rdf_subject, RDF::DC.title, 'Comet in Moominland')
      expect(subject.title).to include 'Comet in Moominland'
    end

    it 'should delete properties when statements are removed' do
      subject << RDF::Statement.new(subject.rdf_subject, RDF::DC.title, 'Comet in Moominland')
      subject.delete RDF::Statement.new(subject.rdf_subject, RDF::DC.title, 'Comet in Moominland')
      expect(subject.title).to eq []
    end
  end

  describe 'big complex graphs' do
    before do
      class DummyPerson
        include ActiveTriples::RDFSource
        configure :type => RDF::URI('http://example.org/Person')
        property :foaf_name, :predicate => RDF::FOAF.name
        property :publications, :predicate => RDF::FOAF.publications, :class_name => 'DummyDocument'
        property :knows, :predicate => RDF::FOAF.knows, :class_name => DummyPerson
      end

      class DummyDocument
        include ActiveTriples::RDFSource
        configure :type => RDF::URI('http://example.org/Document')
        property :title, :predicate => RDF::DC.title
        property :creator, :predicate => RDF::DC.creator, :class_name => 'DummyPerson'
      end

      DummyResource.property :item, :predicate => RDF::DC.relation, :class_name => DummyDocument
    end

    subject { DummyResource.new }

    let (:document1) do
      d = DummyDocument.new
      d.title = 'Document One'
      d
    end

    let (:document2) do
      d = DummyDocument.new
      d.title = 'Document Two'
      d
    end

    let (:person1) do
      p = DummyPerson.new
      p.foaf_name = 'Alice'
      p
    end

    let (:person2) do
      p = DummyPerson.new
      p.foaf_name = 'Bob'
      p
    end

    let (:data) { <<END
_:1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/SomeClass> .
_:1 <http://purl.org/dc/terms/relation> _:2 .
_:2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/Document> .
_:2 <http://purl.org/dc/terms/title> "Document One" .
_:2 <http://purl.org/dc/terms/creator> _:3 .
_:2 <http://purl.org/dc/terms/creator> _:4 .
_:4 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/Person> .
_:4 <http://xmlns.com/foaf/0.1/name> "Bob" .
_:3 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/Person> .
_:3 <http://xmlns.com/foaf/0.1/name> "Alice" .
_:3 <http://xmlns.com/foaf/0.1/knows> _:4 ."
END
    }

    after do
      Object.send(:remove_const, "DummyDocument")
      Object.send(:remove_const, "DummyPerson")
    end

    it 'should allow access to deep nodes' do
      document1.creator = [person1, person2]
      document2.creator = person1
      person1.knows = person2
      subject.item = [document1]
      expect(subject.item.first.creator.first.knows.first.foaf_name).to eq ['Bob']
    end
  end

  describe "callbacks" do
    describe ".before_persist" do
      before do
        class DummyResource
          include ActiveTriples::RDFSource
          def bla
            self.title = "test"
          end
        end
        DummyResource.before_persist :bla
        repository = RDF::Repository.new
        allow(subject).to receive(:repository).and_return(repository)
      end
      it "should call prior to persisting" do
        expect(subject.title).to be_blank
        subject.persist!
        expect(subject.title).to eq ["test"]
      end
    end
  end
end
