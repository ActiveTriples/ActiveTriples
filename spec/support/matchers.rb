# frozen_string_literal: true
require 'spec_helper'

RSpec::Matchers.define :be_a_relation_containing do |*expected|
  match do |actual|
    expect(actual.class).to eq ActiveTriples::Relation
    expect(actual).to contain_exactly(*expected)
    true
  end
end

