require 'spec_helper'
require 'rdf/isomorphic'

describe ActiveTriples::Relation do

  subject do
    described_class.new(double("parent", reflections: []), double("value args"))
  end

  describe "#rdf_subject" do
    let(:parent_resource) { double("parent resource", reflections: {}) }

    subject { described_class.new(parent_resource, double("value args") ) }

    context "when relation has 0 value arguments" do
      before { subject.value_arguments = double(length: 0) }
      it "should raise an error" do
        expect { subject.send(:rdf_subject) }.to raise_error
      end
    end
    context "when term has 1 value argument" do
      before do
        allow(subject.parent).to receive(:rdf_subject) { "parent subject" }
        subject.value_arguments = double(length: 1)
      end
      it "should call `rdf_subject' on the parent" do
        expect(subject.send(:rdf_subject) ).to eq "parent subject"
      end
      it " is a private method" do
        expect { subject.rdf_subject }.to raise_error NoMethodError
      end
    end
    context "when relation has 2 value arguments" do
      before { subject.value_arguments = double(length: 2, first: "first") }
      it "should return the first value argument" do
        expect(subject.send(:rdf_subject) ).to eq "first"
      end
    end
    context "when relation has 3 value arguments" do
      before { subject.value_arguments = double(length: 3) }
      it "should raise an error" do
        expect { subject.send(:rdf_subject)  }.to raise_error
      end
    end
  end

  describe "#valid_datatype?" do
    before do
      allow(subject.parent).to receive(:rdf_subject) { "parent subject" } 
    end

    context "the value is not a Resource" do
      it "should be true if value is a String" do
        expect(subject.send(:valid_datatype?, "foo")).to be true
      end

      it "should be true if value is a Symbol" do
        expect(subject.send(:valid_datatype?, :foo)).to be true
      end

      it "should be true if the value is a Numeric" do
        expect(subject.send(:valid_datatype?, 1)).to be true
        expect(subject.send(:valid_datatype?, 0.1)).to be true
      end

      it "should be true if the value is a Date" do
        expect(subject.send(:valid_datatype?, Date.today)).to be true
      end

      it "should be true if the value is a Time" do
        expect(subject.send(:valid_datatype?, Time.now)).to be true
      end

      it "should be true if the value is a boolean" do
        expect(subject.send(:valid_datatype?, false)).to be true
        expect(subject.send(:valid_datatype?, true)).to be true
      end
    end

    context "the value is a Resource" do
      after { Object.send(:remove_const, :DummyResource) }

      let(:resource) { DummyResource.new }

      context "and the resource class does not include RDF::Isomorphic" do
        before { class DummyResource; include ActiveTriples::RDFSource; end }

        it "should be false" do
          expect(subject.send(:valid_datatype?, resource)).to be false
        end
      end

      context "and the resource class includes RDF:Isomorphic" do
        before do
          class DummyResource
            include ActiveTriples::RDFSource
            include RDF::Isomorphic
          end
        end

        it "should be false" do
          expect(subject.send(:valid_datatype?, resource)).to be false
        end
      end

      context "and the resource class includes RDF::Isomorphic and aliases :== to :isomorphic_with?" do
        before do
          class DummyResource
            include ActiveTriples::RDFSource
            include RDF::Isomorphic
            alias_method :==, :isomorphic_with?
          end
        end

        it "should be false" do
          expect(subject.send(:valid_datatype?, resource)).to be false
        end
      end
    end
  end

  shared_context 'with values' do
    before { resource << RDF::Statement(resource, property, 'value') }

    subject { described_class.new(resource, value_args) }
    let(:resource) { ActiveTriples::Resource.new }
    let(:property) { RDF::URI.new('http://example.com/moomin') }

    let(:value_args) do
      double('value args', 
             length: 1,
             first: 'first',
             last: property)
    end
  end


  describe '#delete' do
    include_context 'with values'

    it 'returns self' do 
      expect(subject.delete).to eq subject
    end
    
    it 'deletes values from property' do
      expect { subject.delete('value') }.to change { subject.result }
                                            .from(['value']).to([])
    end

    it 'deletes multiple values from property' do
      values = [Date.today, 'value2', RDF::Node.new, true]
      resource.set_value(property, values)
      
      expect { subject.delete(*values[0..2]) }.to change { subject.result }
                                            .from(values)
                                            .to(contain_exactly(values.last))
    end
  end

  describe '#empty_property' do
    include_context 'with values'

    it 'returns self' do 
      expect(subject.empty_property).to eq subject
    end

    it 'deletes values from property' do
      expect { subject.empty_property }.to change { subject.result }
                                            .from(['value']).to([])
    end

    it 'deletes multiple values from property' do
      values = [Date.today, 'value2', RDF::Node.new, true]
      resource.set_value(property, values)

      expect { subject.empty_property }.to change { subject.result }
                                            .from(values).to([])
    end
  end
end
