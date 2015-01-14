require 'spec_helper'

describe "nesting attribute behavior" do
  describe ".attributes=" do
    describe "complex properties" do
      before do
        class DummyMADS < RDF::Vocabulary("http://www.loc.gov/mads/rdf/v1#")
          # componentList and Types of components
          property :componentList
          property :Topic
          property :Temporal
          property :PersonalName
          property :CorporateName
          property :ComplexSubject


          # elementList and elementList values
          property :elementList
          property :elementValue
          property :TopicElement
          property :TemporalElement
          property :NameElement
          property :FullNameElement
          property :DateNameElement
        end

        class ComplexResource < ActiveTriples::Resource
          property :topic, predicate: DummyMADS.Topic, class_name: "Topic"
          property :personalName, predicate: DummyMADS.PersonalName, class_name: "PersonalName"
          property :title, predicate: RDF::DC.title


          accepts_nested_attributes_for :topic, :personalName

          class Topic < ActiveTriples::Resource
            property :elementList, predicate: DummyMADS.elementList, class_name: "ComplexResource::ElementList"
            accepts_nested_attributes_for :elementList
          end
          class PersonalName < ActiveTriples::Resource
            property :elementList, predicate: DummyMADS.elementList, class_name: "ComplexResource::ElementList"
            property :extraProperty, predicate: DummyMADS.elementValue, class_name: "ComplexResource::Topic"
            accepts_nested_attributes_for :elementList, :extraProperty
          end
          class ElementList < ActiveTriples::List
            configure type: DummyMADS.elementList
            property :topicElement, predicate: DummyMADS.TopicElement, class_name: "ComplexResource::MadsTopicElement"
            property :temporalElement, predicate: DummyMADS.TemporalElement
            property :fullNameElement, predicate: DummyMADS.FullNameElement
            property :dateNameElement, predicate: DummyMADS.DateNameElement
            property :nameElement, predicate: DummyMADS.NameElement
            property :elementValue, predicate: DummyMADS.elementValue
            accepts_nested_attributes_for :topicElement
          end
          class MadsTopicElement < ActiveTriples::Resource
            configure :type => DummyMADS.TopicElement
            property :elementValue, predicate: DummyMADS.elementValue
          end
        end
      end
      after do
        Object.send(:remove_const, :ComplexResource)
        Object.send(:remove_const, :DummyMADS)
      end
      subject { ComplexResource.new }
      let(:params) do
        { myResource:
          {
            topic_attributes: {
              '0' =>
              {
                elementList_attributes: [{
                  topicElement_attributes: [{
                    id: 'http://library.ucsd.edu/ark:/20775/bb3333333x',
                    elementValue:"Cosmology"
                     }]
                  }]
              },
              '1' =>
              {
                elementList_attributes: [{
                  topicElement_attributes: {'0' => {elementValue:"Quantum Behavior"}}
                }]
              }
            },
            personalName_attributes: [
              {
                id: 'http://library.ucsd.edu/ark:20775/jefferson',
                elementList_attributes: [{
                  fullNameElement: "Jefferson, Thomas",
                  dateNameElement: "1743-1826"
                }]
              }
              #, "Hemings, Sally"
            ],
          }
        }
      end

      describe "on lists" do
        subject { ComplexResource::PersonalName.new }
        it "should accept a hash" do
          subject.elementList_attributes =  [{ topicElement_attributes: {'0' => { elementValue:"Quantum Behavior" }, '1' => { elementValue:"Wave Function" }}}]
          expect(subject.elementList.first[0].elementValue).to eq ["Quantum Behavior"]
          expect(subject.elementList.first[1].elementValue).to eq ["Wave Function"]

        end
        it "should accept an array" do
          subject.elementList_attributes =  [{ topicElement_attributes: [{ elementValue:"Quantum Behavior" }, { elementValue:"Wave Function" }]}]
          expect(subject.elementList.first[0].elementValue).to eq ["Quantum Behavior"]
          expect(subject.elementList.first[1].elementValue).to eq ["Wave Function"]
        end
      end

      context "from nested objects" do
        before do
          # Replace the graph's contents with the Hash
          subject.attributes = params[:myResource]
        end

        it 'should have attributes' do
          expect(subject.topic[0].elementList.first[0].elementValue).to eq ["Cosmology"]
          expect(subject.topic[1].elementList.first[0].elementValue).to eq ["Quantum Behavior"]
          expect(subject.personalName.first.elementList.first.fullNameElement).to eq ["Jefferson, Thomas"]
          expect(subject.personalName.first.elementList.first.dateNameElement).to eq ["1743-1826"]
        end

        it 'should build nodes with ids' do
          expect(subject.topic[0].elementList.first[0].rdf_subject).to eq 'http://library.ucsd.edu/ark:/20775/bb3333333x'
          expect(subject.personalName.first.rdf_subject).to eq  'http://library.ucsd.edu/ark:20775/jefferson'
        end

        it 'should fail when writing to a non-predicate' do
          attributes = { topic_attributes: { '0' => { elementList_attributes: [{ topicElement_attributes: [{ fake_predicate:"Cosmology" }] }]}}}
          expect{ subject.attributes = attributes }.to raise_error ArgumentError
        end

        it 'should fail when writing to a non-predicate with a setter method' do
          attributes = { topic_attributes: { '0' => { elementList_attributes: [{ topicElement_attributes: [{ name:"Cosmology" }] }]}}}
          expect{ subject.attributes = attributes }.to raise_error ArgumentError
        end
      end
    end

    context "a simple model" do
      before do
        class SpecResource < ActiveTriples::Resource
          property :parts, predicate: RDF::DC.hasPart, :class_name=>'Component'
          accepts_nested_attributes_for :parts, allow_destroy: true

          class Component < ActiveTriples::Resource
            property :label, predicate: RDF::DC.title
          end
        end

        SpecResource.accepts_nested_attributes_for *args
      end
      after { Object.send(:remove_const, :SpecResource) }

      let(:args) { [:parts] }
      subject { SpecResource.new }

      context "for an existing B-nodes" do
        before do
          subject.attributes = { parts_attributes: [
                                    {label: 'Alternator'},
                                    {label: 'Distributor'},
                                    {label: 'Transmission'},
                                    {label: 'Fuel Filter'}]}
          subject.parts_attributes = new_attributes
        end

        context "that allows destroy" do
          let(:args) { [:parts, allow_destroy: true] }
          let (:replace_object_id) { subject.parts[1].rdf_subject.to_s }
          let (:remove_object_id) { subject.parts[3].rdf_subject.to_s }

          let(:new_attributes) { [{ id: replace_object_id, label: "Universal Joint" },
                                  { label:"Oil Pump" },
                                  { id: remove_object_id, _destroy: '1', label: "bar1 uno" }] }

          it "should update nested objects" do
            expect(subject.parts.map{|p| p.label.first}).to eq ['Alternator', 'Universal Joint', 'Transmission', 'Oil Pump']
          end
        end

        context "when an id is provided" do
          let(:new_attributes) { [{ id: 'http://example.com/part#1', label: "Universal Joint" }] }

          it "creates a new statement" do
            expect(subject.parts.last.rdf_subject).to eq RDF::URI('http://example.com/part#1')
          end
        end
      end

      context "for an existing resources" do
        before do
          subject.attributes = { parts_attributes: [
                                    { id: 'http://id.loc.gov/authorities/subjects/sh85010251' },
                                    { id: 'http://id.loc.gov/authorities/subjects/sh2001009145' }]}
          subject.parts_attributes = new_attributes
        end

        let(:args) { [:parts] }

        let(:new_attributes) { [{ id: 'http://id.loc.gov/authorities/subjects/sh85010251' },
                                { id: 'http://id.loc.gov/authorities/subjects/sh2001009145' },
                                { id: 'http://id.loc.gov/authorities/subjects/sh85052223' }] }

        it "should update nested objects" do
          expect(subject.parts.map{|p| p.id}).to eq ["http://id.loc.gov/authorities/subjects/sh85010251", "http://id.loc.gov/authorities/subjects/sh2001009145", "http://id.loc.gov/authorities/subjects/sh85052223"]
        end
      end


      context "for a new B-node" do
        context "when called with reject_if" do
          let(:args) { [:parts, reject_if: reject_proc] }
          let(:reject_proc) { lambda { |attributes| attributes[:label] == 'Bar' } }
          let(:new_attributes) { [{ label: "Universal Joint" }, { label: 'Bar'} ] }
          before { subject.parts_attributes = new_attributes }

          it "should call the reject if proc" do
            expect(subject.parts.map(&:label)).to eq [['Universal Joint']]
          end
        end
      end
    end
  end
end
