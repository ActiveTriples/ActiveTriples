require 'spec_helper'

describe ActiveTriples::Resource do

  subject { MyResource.new }

  before(:all) do
    class MyResource < ActiveTriples::Resource
      property :title, predicate: ::RDF::DC.title

      validates_presence_of :title
    end
  end

  after(:all) do
    Object.send(:remove_const, :MyResource)
  end

  describe "validation" do
    it "should have a presence validator on the class" do
      expect(MyResource.validators.first).to be_a(ActiveModel::Validations::PresenceValidator)
    end
    it "should have validation callbacks" do
      expect(MyResource._validate_callbacks).to be_present
    end
    it "should run the validations" do
      expect(subject).to receive(:run_validations!)
      subject.valid?
    end
    it { is_expected.to be_invalid }
  end

end
