require 'spec_helper'

describe ActiveTriples::Term do

  describe "#rdf_subject" do
    subject { described_class.new( double("parent"), double("value args") ) }
    context "when term has 0 value arguments" do
      before { subject.value_arguments = double(length: 0) }
      it "should raise an error" do
        expect { subject.rdf_subject }.to raise_error
      end
    end
    context "when term has 1 value argument" do
      before do
        allow(subject.parent).to receive(:rdf_subject) { "parent subject" }
        subject.value_arguments = double(length: 1)
      end
      it "should call `rdf_subject' on the parent" do
        expect(subject.rdf_subject).to eq "parent subject"
      end
    end
    context "when term has 2 value arguments" do
      before { subject.value_arguments = double(length: 2, first: "first") }
      it "should return the first value argument" do
        expect(subject.rdf_subject).to eq "first"
      end
    end
    context "when term has 3 value arguments" do
      before { subject.value_arguments = double(length: 3) }
      it "should raise an error" do
        expect { subject.rdf_subject }.to raise_error
      end
    end
  end

end
