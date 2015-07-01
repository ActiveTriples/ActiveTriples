require 'spec_helper'

describe 'replace property values' do
  before do
    ActiveTriples::Repositories.add_repository :default, RDF::Repository.new

    class DummyLicenseNR < ActiveTriples::Resource
      configure :type => RDF::URI('http://example.org/SomeClass')
      property :title, :predicate => RDF::DC.title
    end

    class DummyLicense < ActiveTriples::Resource
      configure :type => RDF::URI('http://example.org/SomeClass'),
                :repository => :default
      property :title, :predicate => RDF::DC.title
    end

    class DummyResource < ActiveTriples::Resource
      configure :type => RDF::URI('http://example.org/SomeClass')
      property :title, :predicate => RDF::DC.title
      property :license, :predicate => RDF::DC.license
      # property :license, :predicate => RDF::DC.license, :class_name => DummyLicense
    end
  end
  after do
    Object.send(:remove_const, "DummyResource") if Object
  end

  subject { DummyResource.new('http://example.org/dr1') }

  let( :dl1 ) { DummyLicense.new('http://example.org/dl1') }
  let( :dl2 ) { DummyLicense.new('http://example.org/dl2') }

  let( :dl1_nr ) { DummyLicenseNR.new('http://example.org/dl1_nr') }
  let( :dl2_nr ) { DummyLicenseNR.new('http://example.org/dl2_nr') }


  describe 'changing text property values' do
    it 'should replace property value' do
      subject.title = "foo"
      expect( subject.title ).to eq ["foo"]
      subject.title = "bar"
      expect( subject.title ).to eq ["bar"]
    end

    it 'should append property value' do
      subject.title = "foo"
      expect( subject.title ).to eq ["foo"]
      subject.title << "bar"
      expect( subject.title ).to eq ["foo","bar"]
    end
  end

  context 'when repository specified on class' do
    describe 'changing class property values' do
      it 'should replace property value' do
        subject.license = dl1
        expect( subject.license ).to eq [dl1]
        subject.license = dl2
        expect( subject.license ).to eq [dl2]
      end

      it 'should append property value' do
        subject.license = dl1
        expect( subject.license ).to eq [dl1]
        subject.license << dl2
        expect( subject.license ).to eq [dl1,dl2]
      end
    end
  end

  context 'when no repository specified on class' do
    describe 'changing class property values' do
      it 'should replace property value' do
        subject.license = dl1_nr
        expect( subject.license ).to eq [dl1_nr]
        subject.license = dl2_nr
        expect( subject.license ).to eq [dl2_nr]
      end

      it 'should append property value' do
        subject.license = dl1_nr
        expect( subject.license ).to eq [dl1_nr]
        subject.license << dl2_nr
        expect( subject.license ).to eq [dl1_nr,dl2_nr]
      end
    end
  end

end
