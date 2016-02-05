# frozen_string_literal: true
require 'spec_helper'
require 'rdf/turtle'

describe 'upgrade_from_6_to_8 --' do
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
      context 'and has blank node for body' do
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