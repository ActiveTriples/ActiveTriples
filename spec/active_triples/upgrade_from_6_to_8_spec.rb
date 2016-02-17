# frozen_string_literal: true
require 'spec_helper'
require 'rdf/turtle'

describe 'upgrade_from_6_to_8 --' do
  context 'simulating comment annotation and body' do
    before(:context) do
      class DummyCommentBody
        include ActiveTriples::RDFSource
        configure :type => RDF::URI('http://www.w3.org/2011/content#ContentAsText'), :repository => :default
        property :content, :predicate => RDF::URI('http://www.w3.org/2011/content#chars')
        property :format, :predicate => RDF::URI('http://purl.org/dc/terms/format')
      end

      class DummyCommentAnnotation
        include ActiveTriples::RDFSource
        configure :type => RDF::URI('http://www.w3.org/ns/oa#Annotation'), :repository => :default
        property :hasBody, :predicate => RDF::URI('http://www.w3.org/ns/oa#hasBody'), :class_name => DummyCommentBody
        property :hasTarget, :predicate => RDF::URI('http://www.w3.org/ns/oa#hasTarget')
        property :motivatedBy, :predicate => RDF::URI('http://www.w3.org/ns/oa#motivatedBy')
      end
    end

    describe 'blank_node_child' do
      before(:context) do
        r = RDF::Repository.new
        ActiveTriples::Repositories.repositories[:default] = r
      end

      context 'when loading from graph' do
        before(:context) do
          @anno_url = 'http://my_oa_store/COMMENT_ANNO'
          @comment_value = 'This is a comment.'
          ttl = "<#{@anno_url}> a <http://www.w3.org/ns/oa#Annotation>;
                       <http://www.w3.org/ns/oa#hasBody> [
                         a <http://www.w3.org/2011/content#ContentAsText>;
                         <http://www.w3.org/2011/content#chars> \"#{@comment_value}\" ;
                         <http://purl.org/dc/terms/format> \"text/plain\"
                       ];
                     <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/665>;
                     <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#commenting> ."
          anno_graph = ::RDF::Graph.new.from_ttl ttl
          r = ActiveTriples::Repositories.repositories[:default]
          r << anno_graph
          # puts '=========================================='
          # puts 'Triples in Repository (context: blanknode)'
          # puts '------------------------------------------'
          # puts r.dump :ttl  # => has all triples for anno and body

          @comment_anno = DummyCommentAnnotation.new(RDF::URI.new(@anno_url))
          # puts "\n----------------------------------"
          # puts 'Triples resumed into @comment_anno'
          # puts '----------------------------------'
          # puts @comment_anno.dump :ttl  # => has all triples for anno, but hasBody is []
        end

        it 'populates DummyCommentAnnotation properly' do
          expect(@comment_anno.rdf_subject.to_s).to eq @anno_url
          expect(@comment_anno).to be_a DummyCommentAnnotation
          expect(@comment_anno.type).to include(RDF::URI.new('http://www.w3.org/ns/oa#Annotation'))
          expect(@comment_anno.motivatedBy).to include(RDF::URI.new('http://www.w3.org/ns/oa#commenting'))
          expect(@comment_anno.hasTarget.first.rdf_subject).to eq RDF::URI.new('http://searchworks.stanford.edu/view/665')
        end

        it 'populates DummyCommentBody properly' do
          body = @comment_anno.hasBody.first
          expect(body).to be_a DummyCommentBody
          expect(body.content.first).to eq @comment_value
          expect(body.type).to include(RDF::URI.new('http://www.w3.org/2011/content#ContentAsText'))
        end
      end
    end

    describe 'persisting body with parent strategy' do
      before(:context) do
        r = RDF::Repository.new
        ActiveTriples::Repositories.repositories[:default] = r
      end

      context 'and resuming' do
        before(:context) do
          @anno_url = 'http://my_oa_store/COMMENT_ANNO'
          comment_anno = DummyCommentAnnotation.new(RDF::URI.new(@anno_url))
          comment_anno.hasTarget = RDF::URI.new('http://searchworks.stanford.edu/view/665')
          comment_anno.motivatedBy = RDF::URI.new('http://www.w3.org/ns/oa#commenting')

          @body_url = 'http://my_oa_store/COMMENT_BODY'
          @comment_value = 'This is a comment.'
          comment_body = DummyCommentBody.new(RDF::URI.new(@body_url),comment_anno)
          comment_body.format = 'text/plain'
          comment_body.content = @comment_value

          comment_anno.hasBody = comment_body
          comment_anno.persist!

          # puts "\n\n================================================"
          # puts 'Triples in Repository (context: parent strategy)'
          # puts '------------------------------------------------'
          # r = ActiveTriples::Repositories.repositories[:default]
          # puts r.dump :ttl  # => has all triples for anno and body

          @comment_anno = DummyCommentAnnotation.new(RDF::URI.new(@anno_url))
          # puts "\n----------------------------------"
          # puts 'Triples resumed into @comment_anno'
          # puts '----------------------------------'
          # puts @comment_anno.dump :ttl  # => has all triples for anno, but only type for body
          # puts "\n----------------------------------"
          # puts 'Triples resumed into @comment_anno.hasBody'
          # puts '----------------------------------'
          # body = @comment_anno.hasBody.first
          # puts body.dump :ttl  # => has only type for body

          @comment_body = DummyCommentBody.new(RDF::URI.new(@body_url))
          # puts "\n----------------------------------"
          # puts 'Triples resumed into @comment_body'
          # puts '----------------------------------'
          # puts @comment_body.dump :ttl  # => has all triples for body
        end

        it 'populates DummyCommentAnnotation properly' do
          expect(@comment_anno.rdf_subject.to_s).to eq @anno_url
          expect(@comment_anno).to be_a DummyCommentAnnotation
          expect(@comment_anno.type).to include(RDF::URI.new('http://www.w3.org/ns/oa#Annotation'))
          expect(@comment_anno.motivatedBy).to include(RDF::URI.new('http://www.w3.org/ns/oa#commenting'))
          expect(@comment_anno.hasTarget.first.rdf_subject).to eq RDF::URI.new('http://searchworks.stanford.edu/view/665')
        end

        it 'populates DummyCommentBody properly when resumed as part of annotation' do
          body = @comment_anno.hasBody.first
          expect(body).to be_a DummyCommentBody
          expect(body.content.first).to eq @comment_value
          expect(body.type).to include(RDF::URI.new('http://www.w3.org/2011/content#ContentAsText'))
        end

        it 'populates DummyCommentBody properly when resumed directly' do
          expect(@comment_body).to be_a DummyCommentBody
          expect(@comment_body.content.first).to eq @comment_value
          expect(@comment_body.type).to include(RDF::URI.new('http://www.w3.org/2011/content#ContentAsText'))
        end
      end
    end
  end

  describe 'grandchild with parent strategy' do
    before(:context) do
      class DummyGrandchildResource
        include ActiveTriples::RDFSource
        configure :repository => :default
        property :title, :predicate => 'http://www.example.com/title'
      end

      class DummyChildResource
        include ActiveTriples::RDFSource
        configure :repository => :default
        property :title, :predicate => 'http://www.example.com/title'
        property :child, :predicate => 'http://www.example.com/grandchild', :class => DummyGrandchildResource
      end

      class DummyResource
        include ActiveTriples::RDFSource
        configure :repository => :default
        property :title, :predicate => 'http://www.example.com/title'
        property :child, :predicate => 'http://www.example.com/child', :class => DummyChildResource
      end
    end

    context 'when persisting final_parent followed by destroying final_parent' do
      before(:context) do
        r = RDF::Repository.new
        ActiveTriples::Repositories.repositories[:default] = r

        @pp = DummyResource.new('http://www.example.com/pp')
        @cp = DummyChildResource.new('http://www.example.com/cp',@pp)
        @gp1 = DummyGrandchildResource.new('http://www.example.com/gp1',@cp)
        @gp2 = DummyGrandchildResource.new('http://www.example.com/gp2',@cp)
        @gp3 = DummyGrandchildResource.new('http://www.example.com/gp3',@cp)

        @pp.title = 'Parent with children using ParentStrategy'
        @pp.child = @cp
        @cp.title = 'Child using ParentStrategy'
        @cp.child = [@gp1,@gp2,@gp3]
        @gp1.title = 'Grandchild #1 using ParentStrategy'
        @gp2.title = 'Grandchild #2 using ParentStrategy'
        @gp3.title = 'Grandchild #3 using ParentStrategy'

        @pp.persist!
        # puts "\n\n================================================"
        # puts 'Triples in Repository (context: parent strategy - after saving final_parent)'
        # puts '------------------------------------------------'
        # r = ActiveTriples::Repositories.repositories[:default]
        # puts r.dump :ttl  # => has all triples for pp, cp, gp1, gp2, gp3

        @pp.destroy
        # puts "\n\n================================================"
        # puts 'Triples in Repository (context: parent strategy - after destroying final_parent)'
        # puts '------------------------------------------------'
        # puts r.dump :ttl  # => pp was removed as expected;  cp, gp1, gp2, gp3 remain in repository;  shouldn't they have been removed too?
        #
        # puts "\n\n------------------------------------------------"
        # puts 'Triples in deleted final_parent (pp)'
        # puts '------------------------------------------------'
        # puts @pp.dump :ttl  # => 0 triples as expected
        #
        # puts "\n\n------------------------------------------------"
        # puts 'Triples in parent (cp)'
        # puts '------------------------------------------------'
        # puts @cp.dump :ttl  # => unaffected, but shouldn't it be emptied too?
        #
        # puts "\n\n------------------------------------------------"
        # puts 'Triples in grandchild (gp1)'
        # puts '------------------------------------------------'
        # puts @gp1.dump :ttl  # => unaffected, but shouldn't it be emptied too?
      end

      it 'empties deleted parent' do
        expect(@pp).to be_empty
      end

      it 'empties children ???' do
        expect(@cp).to be_empty
      end

      it 'empties grandchildren ???' do
        expect(@gp1).to be_empty
        expect(@gp2).to be_empty
        expect(@gp3).to be_empty
      end

      it 'removes triples from repository where parent is subject or object' do
        r = ActiveTriples::Repositories.repositories[:default]
        r.statements.to_a.each do |s|
          expect( s.subject.to_s ).to_not eq @pp.rdf_subject.to_s
          expect( s.object.to_s ).to_not eq @pp.rdf_subject.to_s
        end
      end

      it 'removes triples from repository where child is subject or object ???' do
        r = ActiveTriples::Repositories.repositories[:default]
        r.statements.to_a.each do |s|
          expect( s.subject.to_s ).to_not eq @cp.rdf_subject.to_s
          expect( s.object.to_s ).to_not eq @cp.rdf_subject.to_s
        end
      end

      it 'removes triples from repository where grand children are subjects or objects ???' do
        r = ActiveTriples::Repositories.repositories[:default]
        r.statements.to_a.each do |s|
          expect( [@gp1.rdf_subject.to_s, @gp2.rdf_subject.to_s, @gp3.rdf_subject.to_s] ).to_not include s.subject.to_s
          expect( [@gp1.rdf_subject.to_s, @gp2.rdf_subject.to_s, @gp3.rdf_subject.to_s] ).to_not include s.object.to_s
        end
      end
    end

    context 'when persisting final_parent followed by destroying grandchild' do
      before(:context) do
        r = RDF::Repository.new
        ActiveTriples::Repositories.repositories[:default] = r

        @pp = DummyResource.new('http://www.example.com/pp')
        @cp = DummyChildResource.new('http://www.example.com/cp',@pp)
        @gp1 = DummyGrandchildResource.new('http://www.example.com/gp1',@cp)
        @gp2 = DummyGrandchildResource.new('http://www.example.com/gp2',@cp)
        @gp3 = DummyGrandchildResource.new('http://www.example.com/gp3',@cp)

        @pp.title = 'Parent with children using ParentStrategy'
        @pp.child = @cp
        @cp.title = 'Child using ParentStrategy'
        @cp.child = [@gp1,@gp2,@gp3]
        @gp1.title = 'Grandchild #1 using ParentStrategy'
        @gp2.title = 'Grandchild #2 using ParentStrategy'
        @gp3.title = 'Grandchild #3 using ParentStrategy'

        @pp.persist!
        # puts "\n\n================================================"
        # puts 'Triples in Repository (context: parent strategy - after saving final_parent)'
        # puts '------------------------------------------------'
        # r = ActiveTriples::Repositories.repositories[:default]
        # puts r.dump :ttl  # => has all triples for pp, cp, gp1, gp2, gp3

        @gp1.destroy
        # puts "\n\n================================================"
        # puts 'Triples in Repository (context: parent strategy - after destroying grandchild gp1)'
        # puts '------------------------------------------------'
        # puts r.dump :ttl  # => unchanged since final_parent not persisted after destroy
        #
        # puts "\n\n------------------------------------------------"
        # puts 'Triples in final_parent (pp)'
        # puts '------------------------------------------------'
        # puts @pp.dump :ttl  # => has all triples for pp, cp, gp2, gp3 AND 1 for gp1 as child of cp1 which it shouldn't
        #
        # puts "\n\n------------------------------------------------"
        # puts 'Triples in parent (cp)'
        # puts '------------------------------------------------'
        # puts @cp.dump :ttl  # => correctly removed all triples referencing gp1
        #
        # puts "\n\n------------------------------------------------"
        # puts 'Triples in deleted grandchild (gp1)'
        # puts '------------------------------------------------'
        # puts @gp1.dump :ttl  # => 0 triples as expected
      end

      it 'empties deleted grandchild' do
        expect(@gp1).to be_empty
      end

      it 'removes all triples from final_parent where grandchild is subject or object' do
        @pp.statements.to_a.each do |s|
          expect( s.subject.to_s ).to_not eq @gp1.rdf_subject.to_s
          expect( s.object.to_s ).to_not eq @gp1.rdf_subject.to_s
        end
      end

      it 'removes all triples from parent where grandchild is subject or object' do
        @cp.statements.to_a.each do |s|
          expect( s.subject.to_s ).to_not eq @gp1.rdf_subject.to_s
          expect( s.object.to_s ).to_not eq @gp1.rdf_subject.to_s
        end
      end
    end
  end
end