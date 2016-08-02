# frozen_string_literal: true
require 'spec_helper'

RSpec::Matchers.define :be_a_relation_containing do |*expected|
  match do |actual|
    expect(actual.class).to eq ActiveTriples::Relation

    actual_terms = actual.map   { |i| i.respond_to?(:to_term) ? i.to_term : i }
    exp_terms    = expected.map { |i| i.respond_to?(:to_term) ? i.to_term : i }

    expect(actual_terms).to contain_exactly(*exp_terms)
    true
  end
end

