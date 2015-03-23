require 'spec_helper'

describe ActiveTriples do
  describe '.ActiveTriples' do
    it 'outputs a string' do
      expect { described_class.ActiveTripels }.to output.to_stdout
    end
  end
end
