require 'spec_helper'

describe OpenStudio::Analysis::Translator::Excel do
  context "no variables defined" do
    let(:path) { "spec/files/no_variables.xlsx" }
    
    before(:each) do
      @excel = OpenStudio::Analysis::Translator::Excel.new(path)
    end

    it "should have measure path" do
      @excel.measure_path.should eq("./measures")
    end

    it "should have excel data" do
      puts @excel
      @excel.should_not be_nil
    end

    it "should process the excel file" do
      @excel.process.should eq(true)
      
      # after processing the measures directory should be what is in the excel file
      @excel.measure_path.should eq(File.expand_path(File.join("spec","files","measures")))
    end

    it "should not work because no variables defined" do
      #old_path = @excel.measure_path
      #@excel.measure_path = "path/does/not/exist"
      #
    end
    
    it "should export to a JSON" do
      @excel.process
      expect {@excel.save_analysis }.to raise_error("Argument 'r_value' did not process.  Most likely it did not have all parameters defined.")
    end

  end
end



