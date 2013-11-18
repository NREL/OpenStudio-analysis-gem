require 'spec_helper'

describe OpenStudio::Analysis::ServerApi do
  context "create a new instance" do
    before(:all) do
      @api = OpenStudio::Analysis::ServerApi.new
    end
    
    it "should set the default host to localhost" do
      @api.hostname.should eq("http://localhost:8080")
    end

  end
end
