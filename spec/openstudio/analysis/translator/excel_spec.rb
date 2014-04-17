require 'spec_helper'

describe OpenStudio::Analysis::Translator::Excel do
  context "no variables defined" do
    let(:path) { "spec/files/no_variables.xlsx" }
  
    before(:each) do
      @excel = OpenStudio::Analysis::Translator::Excel.new(path)
    end
  
    it "should have measure path" do
      expect(@excel.measure_path).to eq("./measures")
    end
  
    it "should have excel data" do
      puts @excel
      expect(@excel).not_to be_nil
    end
  
    it "should process the excel file" do
      expect(@excel.process).to eq(true)
  
      # after processing the measures directory should be what is in the excel file
      expect(@excel.measure_path).to eq(File.expand_path(File.join("spec", "files", "measures")))
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
      expect(@excel.models.first).not_to be_nil
      expect(@excel.models.first[:name]).to eq("small_seed")
    end
  
    it "should have a weather file" do
      expect(@excel.weather_files.first).not_to be_nil
      puts @excel.weather_files.first
      expect(@excel.weather_files.first.include?("partial_weather.epw")).to eq(true)
    end
  
    it "should have notes and source" do
      @excel.variables['data'].each do |measure|
        measure['variables'].each do |var|
          if var['machine_name'] == 'lighting_power_reduction'
            expect(var['distribution']['source']).to eq("some data source")
          elsif var['machine_name'] == 'demo_cost_initial_const'
            expect(var['notes']).to eq("some note")
          end
        end
      end
    end
  
    it "should write a json" do
      @excel.save_analysis
      expect(File).to exist("spec/files/export/analysis/small_seed.json")
      expect(File).to exist("spec/files/export/analysis/small_seed.zip")
  
      expect(JSON.parse(File.read("spec/files/export/analysis/small_seed.json"))).not_to be_nil
  
    end
  end
  
  context "setup version 0.1.9" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/setup_version_2.xlsx")
      @excel.process
    end
  
    it "should have a version and machine name" do
      expect(@excel.version).to eq("0.1.9")
      expect(@excel.machine_name).to eq("example_analysis")
    end
    it "should have the new settings" do
      expect(@excel.settings["server_instance_type"]).to eq("m2.xlarge")
    end
  
    it "should have algorithm setup" do
      expect(@excel.algorithm["number_of_samples"]).to eq(100)
      expect(@excel.algorithm["number_of_generations"]).to eq(20)
      expect(@excel.algorithm["sample_method"]).to eq("all_variables")
      expect(@excel.algorithm["number_of_generations"]).to be_a Integer
      expect(@excel.algorithm["tolerance"]).to eq(0.115)
      expect(@excel.algorithm["tolerance"]).to be_a Float
  
    end
  
    it "should create a valid hash" do
      h = @excel.create_analysis_hash
  
      expect(h['analysis']['problem']['analysis_type']).to eq("lhs")
      expect(h['analysis']['problem']['algorithm']).not_to be_nil
      expect(h['analysis']['problem']['algorithm']['number_of_samples']).to eq(100)
      expect(h['analysis']['problem']['algorithm']['sample_method']).to eq("all_variables")
    end
  end
  
  context "proxy setup" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/proxy.xlsx")
      @excel.process
    end
  
    it "should have a proxy setting" do
      expect(@excel.settings["proxy_host"]).to eq("192.168.0.1")
      expect(@excel.settings["proxy_port"]).to eq(8080)
      expect(@excel.settings["proxy_username"]).to be_nil
  
    end
  end
  
  context "proxy setup with user" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/proxy_user.xlsx")
      @excel.process
    end
  
    it "should have a user" do
      expect(@excel.settings["proxy_host"]).to eq("192.168.0.1")
      expect(@excel.settings["proxy_port"]).to eq(8080)
      expect(@excel.settings["proxy_username"]).to eq("a_user")
    end
  end
  
  context "discrete variables" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/discrete_variables.xlsx")
      @excel.process
    end
  
    it "should have parsed the spreadsheet" do
      @excel.variables['data'].each do |measure|
        measure['variables'].each do |var|
  
        end
      end
    end
  
    it "should save the file" do
      @excel.save_analysis
    end
  end
  
  context "discrete with dynamic columns" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/discrete_dynamic_columns.xlsx")
      @excel.process
    end
  
    it "should have parsed the spreadsheet" do
      @excel.variables['data'].each do |measure|
        measure['variables'].each do |var|
          puts var.inspect
        end
      end
    end
  
    it "should save the file" do
      @excel.save_analysis
    end
  end
  
  context "setup output variables" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/outputvars.xlsx")
      @excel.process
    end
  
    it "should have a model" do
      expect(@excel.models.first).not_to be_nil
      expect(@excel.models.first[:name]).to eq("output_vars")
    end
  
    it "should have a weather file" do
      expect(@excel.weather_files.first).not_to be_nil
      puts @excel.weather_files.first
      expect(@excel.weather_files.first.include?("partial_weather.epw")).to eq(true)
    end
  
    it "should have notes and source" do
      @excel.variables['data'].each do |measure|
        measure['variables'].each do |var|
          if var['machine_name'] == 'lighting_power_reduction'
            expect(var['distribution']['source']).to eq("some data source")
          elsif var['machine_name'] == 'demo_cost_initial_const'
            expect(var['notes']).to eq("some note")
          end
        end
      end
    end
  
    it "should have typed booleans" do
      expect(@excel.run_setup['use_server_as_worker']).to eq(true)
      expect(@excel.run_setup['allow_multiple_jobs']).to eq(true)
    end
    
    it "should have algorithm setup" do
      expect(@excel.algorithm["number_of_samples"]).to eq(100)
      expect(@excel.algorithm["number_of_generations"]).to eq(20)
      expect(@excel.algorithm["sample_method"]).to eq("all_variables")
      expect(@excel.algorithm["number_of_generations"]).to be_a Integer
      #expect(@excel.algorithm["tolerance"]).to eq(0.115)
      #expect(@excel.algorithm["tolerance"]).to be_a Float
  
    end
  
    it "should create a valid hash" do
      h = @excel.create_analysis_hash
  
      expect(h['analysis']['problem']['analysis_type']).to eq("nsga")
      expect(h['analysis']['problem']['algorithm']).not_to be_nil
      expect(h['analysis']['problem']['algorithm']['number_of_samples']).to eq(100)
      expect(h['analysis']['problem']['algorithm']['sample_method']).to eq("all_variables")
    end
  
  
    it "should write a json" do
      @excel.save_analysis
      expect(File).to exist("spec/files/export/analysis/output_vars.json")
      expect(File).to exist("spec/files/export/analysis/output_vars.zip")
  
      expect(JSON.parse(File.read("spec/files/export/analysis/output_vars.json"))).not_to be_nil
  
    end
  end
  
  context "version 0.1.10" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/template_input_0.1.10.xlsx")
    end
    
    it "should process" do
      expect(@excel.process).to eq(true)
    end
    
    it "should have new setting variables" do
      puts @excel.settings.inspect
      expect(@excel.settings["user_id"]).to eq('new_user')
      expect(@excel.settings["openstudio_server_version"]).to eq('1.3.2')
      expect(@excel.cluster_name).to eq('analysis_cluster')
      puts @excel.run_setup.inspect
      expect(@excel.run_setup["analysis_name"]).to eq('LHS Example Project')
    end
  end

  context "version 0.2.0" do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new("spec/files/template_0_2_0.xlsx")
    end

    it "should process" do
      expect(@excel.process).to eq(true)
    end

    it "should have new setting variables" do
      puts @excel.settings.inspect
      expect(@excel.settings["user_id"]).to eq('new_user')
      expect(@excel.settings["openstudio_server_version"]).to eq('1.3.2')
      expect(@excel.cluster_name).to eq('analysis_cluster_name')
      puts @excel.run_setup.inspect
      expect(@excel.run_setup["analysis_name"]).to eq('Name goes here')
    end
    
    it "should have the new measure directory column" do
      expect(@excel.variables['data'][1]['measure_file_name_directory']).to eq('ReduceLightingLoadsByPercentage')
    end

    it "should write a json" do
       @excel.save_analysis
    end
  end
  

end



