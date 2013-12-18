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
      @excel.measure_path.should eq(File.expand_path(File.join("spec", "files", "measures")))
    end

    it "should not work because no variables defined" do
      #old_path = @excel.measure_path
      #@excel.measure_path = "path/does/not/exist"
      #
    end

    it "should not export to a JSON" do
      @excel.process
      expect { @excel.save_analysis }.to raise_error("Argument 'r_value' did not process.  Most likely it did not have all parameters defined.")
    end
  end

  context "small list of incomplete variables" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/small_list_incomplete.xlsx")
    end

    it "should fail to process" do
      expect { @excel.process }.to raise_error("Variable adjust_thermostat_setpoints_by_degrees:cooling_adjustment must have a mean")
    end
  end

  context "small list with with repeated variable names" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/small_list_repeat_vars.xlsx")
    end

    it "should fail to process" do
      expect { @excel.process }.to raise_error("duplicate variable names found in list [\"Insulation R-value (ft^2*h*R/Btu).\"]")
    end
  end

  context "small list of variables should not validate" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/small_list_validation_errors.xlsx")
    end

    it "should fail to process" do
      expect { @excel.process }.to raise_error("Variable min is greater than variable max for adjust_thermostat_setpoints_by_degrees:heating_adjustment")
    end
  end

  context "small list of variables" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/small_list.xlsx")
      @excel.process
    end
    it "should have a model" do
      @excel.models.first.should_not be_nil
      puts @excel.models.first[:name].should eq("small_seed")
    end

    it "should have a weather file" do
      @excel.weather_files.first.should_not be_nil
      @excel.weather_files.first.include?("partial_weather.epw").should be_true
    end
    
    it "should write a json" do
      @excel.save_analysis
      expect(File).to exist("spec/files/export/analysis/small_seed.json")
      expect(File).to exist("spec/files/export/analysis/small_seed.zip")
      
      expect(JSON.parse(File.read("spec/files/export/analysis/small_seed.json"))).not_to be_nil
      
    end
  end


end



