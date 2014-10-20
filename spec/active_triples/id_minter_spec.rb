require 'spec_helper'

describe ActiveTriples::IDMinter do

  describe "#generate_id" do
    before (:all) do
      @timeHashMinter = lambda do |digit_count|
        rnd_id = 0
        rnd_id = Time.now.hash until rnd_id != 0
        rnd_id *= -1 if rnd_id < 0
        rnd_id /= 10 until rnd_id < (10**digit_count)
        rnd_id
      end
    end

    subject {DummyResourceWithBaseURI.new('1')}

    before do
      class DummyResource < ActiveTriples::Resource
        configure :type => RDF::URI('http://example.org/SomeClass')
        property :title, :predicate => RDF::DC.title
      end
      class DummyResourceWithBaseURI < ActiveTriples::Resource
        configure :base_uri => "http://example.org",
                  :type => RDF::URI("http://example.org/SomeClass"),
                  :repository => :default
      end
      ActiveTriples::Repositories.add_repository :default, RDF::Repository.new
    end
    after do
      Object.send(:remove_const, "DummyResourceWithBaseURI") if Object
      Object.send(:remove_const, "DummyResource") if Object
      ActiveTriples::Repositories.clear_repositories!
    end

    context "when class doesn't have base_uri defined" do
      it "should raise an Exception" do
        expect{ ActiveTriples::IDMinter.generate_id(DummyResource) }.to raise_error(RuntimeError, 'Requires base_uri to be defined in for_class.')
      end
    end
    context "when minter_func is not passed in" do
      it "should use default minter function" do
        id = ActiveTriples::IDMinter.generate_id(DummyResourceWithBaseURI)
        expect(id).to be_kind_of String
        expect(id.length).to be 36
      end
    end
    context "when all IDs available" do
      it "should generate an ID" do
        expect(ActiveTriples::IDMinter.generate_id(DummyResourceWithBaseURI,@timeHashMinter,1)).to be_between(1,9)
      end
    end
    context "when some IDs available" do
      before do
        DummyResourceWithBaseURI.new('3').persist!
        DummyResourceWithBaseURI.new('4').persist!
        DummyResourceWithBaseURI.new('8').persist!
      end
      after do
        DummyResourceWithBaseURI.new('3').destroy!
        DummyResourceWithBaseURI.new('4').destroy!
        DummyResourceWithBaseURI.new('8').destroy!
      end

      it "should generate an ID not already in use" do
        id = ActiveTriples::IDMinter.generate_id(DummyResourceWithBaseURI,@timeHashMinter,1)
        expect(id).to be_between(1,9)
        expect(id).not_to eq 3
        expect(id).not_to eq 4
        expect(id).not_to eq 8
      end
    end

    context "when no IDs available" do
      before do
        1.upto(9) { |id| DummyResourceWithBaseURI.new(id).persist! }
      end
      after do
        1.upto(9) { |id| DummyResourceWithBaseURI.new(id).destroy! }
      end

      it "should raise an Exception" do
        expect{ ActiveTriples::IDMinter.generate_id(DummyResourceWithBaseURI,@timeHashMinter,1) }.
            to raise_error(RuntimeError, "Available ID not found.  Exceeded maximum tries.")
      end
    end
  end

end
