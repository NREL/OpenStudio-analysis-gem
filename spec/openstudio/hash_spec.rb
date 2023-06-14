# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'spec_helper'

describe Hash do
  context 'deep key' do
    before :all do
      @h = {
        a: ['array_1', 'array_2'],
        b: {
          c: {
            'string_key' => 'finally'
          }
        }
      }
    end

    it 'should find the key' do
      expect(@h.deep_find(:a)).to eq ['array_1', 'array_2']
      expect(@h.deep_find('string_key')).to eq 'finally'
    end
  end
end
