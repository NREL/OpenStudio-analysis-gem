require 'spec_helper'

describe Hash do
  context 'deep key' do
    before :all do
      @h = {
        a: %w(array_1 array_2),
        b: {
          c: {
            'string_key' => 'finally'
          }
        }
      }
    end

    it 'should find the key' do
      expect(@h.deep_find(:a)).to eq %w(array_1 array_2)
      expect(@h.deep_find('string_key')).to eq 'finally'
    end
  end
end
