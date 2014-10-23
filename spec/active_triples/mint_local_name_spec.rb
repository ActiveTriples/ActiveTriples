require 'spec_helper'

describe ActiveTriples::MintLocalName do

  describe "#generate_local_name" do
    before (:all) do
      @timeHashMinter_lambda = lambda do |digit_count|
        rnd_id = 0
        rnd_id = Time.now.hash until rnd_id != 0
        rnd_id *= -1 if rnd_id < 0
        rnd_id /= 10 until rnd_id < (10**digit_count)
        "lambda_#{rnd_id}"
      end

      @timeHashMinter_proc = proc do |digit_count|
        rnd_id = 0
        rnd_id = Time.now.hash until rnd_id != 0
        rnd_id *= -1 if rnd_id < 0
        rnd_id /= 10 until rnd_id < (10**digit_count)
        "proc_#{rnd_id}"
      end

      # See also timeHashMinter_method defined in DummyResourceWithBaseURI class below.
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

        def self.timeHashMinter_method( digit_count )
          rnd_id = 0
          rnd_id = Time.now.hash until rnd_id != 0
          rnd_id *= -1 if rnd_id < 0
          rnd_id /= 10 until rnd_id < (10**digit_count)
          "method_#{rnd_id}"
        end
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
        expect{ ActiveTriples::MintLocalName.generate_local_name(DummyResource) }.to raise_error(RuntimeError, 'Requires base_uri to be defined in for_class.')
      end
    end

    context "when all IDs available" do
      context "and no minter function is passed in" do
        it "should generate an ID using default minter function" do
          id = ActiveTriples::MintLocalName.generate_local_name(DummyResourceWithBaseURI)
          expect(id).to be_kind_of String
          expect(id.length).to be 36
        end
      end

      context "and minter function is passed as block" do
        it "should generate an ID with passed in minter function block" do
          id = ActiveTriples::MintLocalName.generate_local_name(DummyResourceWithBaseURI,10,1) do |digit_count|
            rnd_id = 0
            rnd_id = Time.now.hash until rnd_id != 0
            rnd_id *= -1 if rnd_id < 0
            rnd_id /= 10 until rnd_id < (10**digit_count)
            rnd_id
          end
          expect(id).to be_between(1,9)
        end
      end

      context "and minter function is passed as proc in block" do
        it "should generate an ID with passed in proc in block" do
          id = ActiveTriples::MintLocalName.generate_local_name(DummyResourceWithBaseURI) { @timeHashMinter_proc.call(1) }
          expect(id[0..4]).to eq "proc_"
          expect(id[5..id.length].to_i).to be_between(1,9)
        end
      end

      context "and minter function is passed address to proc" do
        it "should generate an ID with passed in proc" do
          id = ActiveTriples::MintLocalName.generate_local_name(DummyResourceWithBaseURI,10,1,&@timeHashMinter_proc)
          expect(id[0..4]).to eq "proc_"
          expect(id[5..id.length].to_i).to be_between(1,9)
        end
      end

      context "and minter function is passed as method in block" do
        it "should generate an ID with passed in method" do
          id = ActiveTriples::MintLocalName.generate_local_name(DummyResourceWithBaseURI) { DummyResourceWithBaseURI.timeHashMinter_method (1) }
          expect(id[0..6]).to eq "method_"
          expect(id[7..id.length].to_i).to be_between(1,9)
        end
      end

    end
    context "when some IDs available" do
      before do
        DummyResourceWithBaseURI.new('proc_3').persist!
        DummyResourceWithBaseURI.new('proc_4').persist!
        DummyResourceWithBaseURI.new('proc_8').persist!
      end
      after do
        DummyResourceWithBaseURI.new('proc_3').destroy!
        DummyResourceWithBaseURI.new('proc_4').destroy!
        DummyResourceWithBaseURI.new('proc_8').destroy!
      end

      it "should generate an ID not already in use" do
        id = ActiveTriples::MintLocalName.generate_local_name(DummyResourceWithBaseURI) { @timeHashMinter_proc.call(1) }
        expect(id[0..4]).to eq "proc_"
        expect(id[5..id.length].to_i).to be_between(1,9)
        expect(id).not_to eq 'proc_3'
        expect(id).not_to eq 'proc_4'
        expect(id).not_to eq 'proc_8'
      end
    end

    context "when no IDs available" do
      before do
        1.upto(9) { |id| DummyResourceWithBaseURI.new("proc_#{id}").persist! }
      end
      after do
        1.upto(9) { |id| DummyResourceWithBaseURI.new("proc_#{id}").destroy! }
      end

      it "should raise an Exception" do
        expect{ ActiveTriples::MintLocalName.generate_local_name(DummyResourceWithBaseURI) { @timeHashMinter_proc.call(1) } }.
            to raise_error(RuntimeError, "Available ID not found.  Exceeded maximum tries.")
      end
    end
  end

end
