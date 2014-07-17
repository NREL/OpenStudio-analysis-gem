require 'spec_helper'

describe OpenStudio::Analysis::ServerApi do
  before :all do
    @host = 'http://localhost:8080'
  end

  context 'create a new object instance' do
    before(:all) do
      @api = OpenStudio::Analysis::ServerApi.new
    end

    it 'should set the default host to localhost' do
      expect(@api.hostname).to eq(@host)
    end
  end

  context 'test not localhost' do
    it 'should have a not localhost URL' do
      options = {hostname: 'http://abc.def.ghi'}
      api = OpenStudio::Analysis::ServerApi.new(options)
      expect(api.hostname).to eq(options[:hostname])
    end
  end
end
