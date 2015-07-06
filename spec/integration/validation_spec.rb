require 'spec_helper'

describe "Validations" do
  before do
    class TestResource < ActiveTriples::Resource
      class TestValidator  < ActiveModel::EachValidator
        def validate_each(record, attribute, values)
          record.errors.add :base, "not valid" if values.empty?
        end
      end

      property :title, predicate: ::RDF::DC.title

      validates_with TestValidator, attributes: [:title]
    end
  end

  after do
    Object.send(:remove_const, :TestResource)
  end

  subject { TestResource.new }

  context "when it is not valid" do
    it { is_expected.not_to be_valid }
  end

  context "when it is valid" do
    before do
      subject.title = ["It's valid"]
    end
    it { is_expected.to be_valid }
  end

end
