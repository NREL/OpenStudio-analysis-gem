require 'spec_helper'

describe OpenStudio::Analysis::ServerApi do
  context "create a new localhost instance" do
    before(:all) do
      @api = OpenStudio::Analysis::ServerApi.new
    end

    it "should set the default host to localhost" do
      @api.hostname.should eq("http://localhost:8080")
    end
  end

  context "test not localhost" do
    it "should have a not localhost URL" do
      options = {hostname: "http://abc.def.ghi"}
      api = OpenStudio::Analysis::ServerApi.new(options)
      api.hostname.should eq(options[:hostname])
      
    end
  end


end
