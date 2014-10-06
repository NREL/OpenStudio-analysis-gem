require 'spec_helper'

describe OpenStudio::Analysis::Translator::Excel do
  before :all do
    clean_dir = File.expand_path 'spec/files/export/analysis'

    if Dir.exist? clean_dir
      FileUtils.rm_rf clean_dir
    end
  end

  context 'no variables defined' do
    let(:path) { 'spec/files/0_1_09_no_variables.xlsx' }

    before(:each) do
      @excel = OpenStudio::Analysis::Translator::Excel.new(path)
    end

    it 'should have excel data' do
      puts @excel
      expect(@excel).not_to be_nil
    end

    it 'should process the excel file' do
      expect(@excel.process).to eq(true)

      # after processing the measures directory should be what is in the excel file
      expect(@excel.measure_paths[0]).to eq(File.expand_path(File.join('spec', 'files', 'measures')))
    end

    it 'should not work because no variables defined' do
      # old_path = @excel.measure_path
      # @excel.measure_path = "path/does/not/exist"
      #
    end

    it 'should not export to a JSON' do
      @excel.process

    end
  end

  context 'small list of incomplete variables' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_09_small_list_incomplete.xlsx')
    end

    it 'should fail to process' do
      expect { @excel.process }.to raise_error('Variable adjust_thermostat_setpoints_by_degrees:cooling_adjustment must have a mean')
    end
  end

  context 'small list with with repeated variable names' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_09_small_list_repeat_vars.xlsx')
    end

    it 'should fail to process' do
      expect { @excel.process }.to raise_error("duplicate variable names found in list [\"Insulation R-value (ft^2*h*R/Btu).\"]")
    end
  end

  context 'small list of variables should not validate' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_09_small_list_validation_errors.xlsx')
    end

    it 'should fail to process' do
      error_message = 'Variable min is greater than variable max for adjust_thermostat_setpoints_by_degrees:heating_adjustment'
      expect { @excel.process }.to raise_error(error_message)
    end
  end

  context 'small list of variables' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_09_small_list.xlsx')
      @excel.process
    end
    it 'should have a model' do
      expect(@excel.models.first).not_to be_nil
      expect(@excel.models.first[:name]).to eq('small_seed')
    end

    it 'should have a weather file' do
      expect(@excel.weather_files.first).not_to be_nil
      puts @excel.weather_files.first
      expect(@excel.weather_files.first.include?('partial_weather')).to eq(true)
    end

    it 'should have notes and source' do
      @excel.variables['data'].each do |measure|
        measure['variables'].each do |var|
          if var['machine_name'] == 'lighting_power_reduction'
            expect(var['distribution']['source']).to eq('some data source')
          elsif var['machine_name'] == 'demo_cost_initial_const'
            expect(var['notes']).to eq('some note')
          end
        end
      end
    end

    it 'should write a json' do
      @excel.save_analysis
      expect(File).to exist('spec/files/export/analysis/small_seed.json')
      expect(File).to exist('spec/files/export/analysis/small_seed.zip')

      expect(JSON.parse(File.read('spec/files/export/analysis/small_seed.json'))).not_to be_nil

    end
  end

  context 'setup version 0.1.9' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_09_setup_version_2.xlsx')
      @excel.process
    end

    it 'should have a version and analysis name in machine format' do
      expect(@excel.version).to eq('0.1.9')
      expect(@excel.analysis_name).to eq('example_analysis')
    end
    it 'should have the new settings' do
      expect(@excel.settings['server_instance_type']).to eq('m2.xlarge')
    end

    it 'should have algorithm setup' do
      expect(@excel.algorithm['number_of_samples']).to eq(100)
      expect(@excel.algorithm['number_of_generations']).to eq(20)
      expect(@excel.algorithm['sample_method']).to eq('all_variables')
      expect(@excel.algorithm['number_of_generations']).to be_a Integer
      expect(@excel.algorithm['tolerance']).to eq(0.115)
      expect(@excel.algorithm['tolerance']).to be_a Float

    end

    it 'should create a valid hash' do
      h = @excel.create_analysis_hash

      expect(h['analysis']['problem']['analysis_type']).to eq('lhs')
      expect(h['analysis']['problem']['algorithm']).not_to be_nil
      expect(h['analysis']['problem']['algorithm']['number_of_samples']).to eq(100)
      expect(h['analysis']['problem']['algorithm']['sample_method']).to eq('all_variables')
    end
  end

  context 'proxy setup' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_10_proxy.xlsx')
      @excel.process
    end

    it 'should have a proxy setting' do
      expect(@excel.settings['proxy_host']).to eq('192.168.0.1')
      expect(@excel.settings['proxy_port']).to eq(8080)
      expect(@excel.settings['proxy_username']).to be_nil
    end
  end

  context 'proxy setup with user' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_10_proxy_user.xlsx')
      @excel.process
    end

    it 'should have a user' do
      expect(@excel.settings['proxy_host']).to eq('192.168.0.1')
      expect(@excel.settings['proxy_port']).to eq(8080)
      expect(@excel.settings['proxy_username']).to eq('a_user')
    end
  end

  context 'discrete variables' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_11_discrete_variables.xlsx')
      @excel.process
    end

    it 'should have parsed the spreadsheet' do
      @excel.variables['data'].each do |measure|
        measure['variables'].each do |var|
          # TODO: Add some tests!
          if var['name'] == 'alter_design_days'
            puts var.inspect
            expect(var['type']).to eq 'bool'
            expect(eval(var['distribution']['discrete_values'])).to match_array %w(true false)
            expect(eval(var['distribution']['discrete_weights'])).to match_array [0.8, 0.2]
          end
        end
      end
    end

    it 'should save the file' do
      @excel.save_analysis
      expect(File.exist?('spec/files/export/analysis/0_1_11_discrete_variables.json')).to eq true
      expect(File.exist?('spec/files/export/analysis/0_1_11_discrete_variables.zip')).to eq true
    end
  end

  context 'discrete with dynamic columns' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_12_discrete_dynamic_columns.xlsx')
      @excel.process
    end

    it 'should have parsed the spreadsheet' do
      @excel.variables['data'].each do |measure|
        measure['variables'].each do |_var|
          # TODO: test something?
        end
      end
    end

    it 'should save the file' do
      @excel.save_analysis
      expect(File.exist?('spec/files/export/analysis/0_1_12_discrete_dynamic_columns.json')).to eq true
      expect(File.exist?('spec/files/export/analysis/0_1_12_discrete_dynamic_columns.zip')).to eq true
    end
  end

  context 'setup output variables' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_09_outputvars.xlsx')
      @excel.process
    end

    it 'should have a model' do
      expect(@excel.models.first).not_to be_nil
      expect(@excel.models.first[:name]).to eq('0_1_09_outputvars')
    end

    it 'should have a weather file' do
      expect(@excel.weather_files.first).not_to be_nil
      puts @excel.weather_files.first
      expect(@excel.weather_files.first.include?('partial_weather')).to eq(true)
    end

    it 'should have notes and source' do
      @excel.variables['data'].each do |measure|
        measure['variables'].each do |var|
          if var['machine_name'] == 'lighting_power_reduction'
            expect(var['distribution']['source']).to eq('some data source')
          elsif var['machine_name'] == 'demo_cost_initial_const'
            expect(var['notes']).to eq('some note')
          end
        end
      end
    end

    it 'should have typed booleans' do
      expect(@excel.run_setup['use_server_as_worker']).to eq(true)
      expect(@excel.run_setup['allow_multiple_jobs']).to eq(true)
    end

    it 'should have algorithm setup' do
      expect(@excel.algorithm['number_of_samples']).to eq(100)
      expect(@excel.algorithm['number_of_generations']).to eq(20)
      expect(@excel.algorithm['sample_method']).to eq('all_variables')
      expect(@excel.algorithm['number_of_generations']).to be_a Integer
      # expect(@excel.algorithm["tolerance"]).to eq(0.115)
      # expect(@excel.algorithm["tolerance"]).to be_a Float

    end

    it 'should create a valid hash' do
      h = @excel.create_analysis_hash

      expect(h['analysis']['problem']['analysis_type']).to eq('nsga')
      expect(h['analysis']['problem']['algorithm']).not_to be_nil
      expect(h['analysis']['problem']['algorithm']['number_of_samples']).to eq(100)
      expect(h['analysis']['problem']['algorithm']['sample_method']).to eq('all_variables')
    end

    it 'should write a json' do
      @excel.save_analysis
      expect(File).to exist('spec/files/export/analysis/0_1_09_outputvars.json')
      expect(File).to exist('spec/files/export/analysis/0_1_09_outputvars.zip')
      expect(JSON.parse(File.read('spec/files/export/analysis/0_1_09_outputvars.json'))).not_to be_nil
    end
  end

  context 'version 0.1.10' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_1_10_template_input.xlsx')
    end

    it 'should process' do
      expect(@excel.process).to eq(true)
    end

    it 'should have new setting variables' do
      puts @excel.settings.inspect
      expect(@excel.settings['user_id']).to eq('new_user')
      expect(@excel.settings['openstudio_server_version']).to eq('1.3.2')
      expect(@excel.cluster_name).to eq('analysis_cluster')
      puts @excel.run_setup.inspect
      expect(@excel.run_setup['analysis_name']).to eq('LHS Example Project')
    end
  end

  context 'version 0.2.0' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_2_0_template.xlsx')
    end

    it 'should process' do
      expect(@excel.process).to eq(true)
    end

    it 'should have new setting variables' do
      puts @excel.settings.inspect
      expect(@excel.settings['user_id']).to eq('new_user')
      expect(@excel.settings['openstudio_server_version']).to eq('1.3.2')
      expect(@excel.cluster_name).to eq('analysis_cluster_name')
      puts @excel.run_setup.inspect
      expect(@excel.run_setup['analysis_name']).to eq('Name goes here')
    end

    it 'should have the new measure directory column' do
      expect(@excel.variables['data'][1]['measure_file_name_directory']).to eq('ReduceLightingLoadsByPercentage')
    end

    it 'should write a json' do
      @excel.save_analysis
    end
  end

  context 'version 0.2.0 simple' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_2_0_template_simpletest.xlsx')
    end

    it 'should process' do
      expect(@excel.process).to eq(true)
    end

    it 'should have new setting variables' do
      puts @excel.settings.inspect
      expect(@excel.settings['user_id']).to eq('new_user')
      expect(@excel.settings['openstudio_server_version']).to eq('1.3.2')
      puts @excel.run_setup.inspect
    end

    it 'should have the new measure directory column' do
      expect(@excel.variables['data'][0]['measure_file_name_directory']).to eq('ExampleMeasure')
      expect(@excel.variables['data'][0]['display_name']).to eq('Baseline')
    end

    it 'should write a json' do
      @excel.save_analysis
      expect(File.exist?('spec/files/export/analysis/0_2_0_template_simpletest.json')).to eq true
      expect(File.exist?('spec/files/export/analysis/0_2_0_template_simpletest.zip')).to eq true
    end
  end

  context 'version 0.3.0 objective functions' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_3_0_outputs.xlsx')
    end

    it 'should process' do
      expect(@excel.process).to eq(true)
    end

    it 'should have new setting variables' do
      puts @excel.settings.inspect
      expect(@excel.settings['user_id']).to eq('new_user')
      expect(@excel.settings['openstudio_server_version']).to eq('1.6.1')
      puts @excel.run_setup.inspect
    end

    it 'should have typed outputs' do
      h = @excel.create_analysis_hash
      expect(h['analysis']['output_variables']).to be_an Array
      h['analysis']['output_variables'].each do |o|
        if o['name'] == 'standard_report_legacy.total_energy'
          expect(o['variable_type']).to eq 'Double'
          expect(o['objective_function']).to eq true
          expect(o['objective_function_index']).to eq 0
          expect(o['objective_function_target']).to eq nil
          expect(o['scaling_factor']).to eq nil
          expect(o['objective_function_group']).to eq 1
        end
        if o['name'] == 'standard_report_legacy.total_source_energy'
          expect(o['variable_type']).to eq 'Double'
          expect(o['objective_function']).to eq true
          expect(o['objective_function_index']).to eq 1
          expect(o['objective_function_target']).to eq 25.1
          expect(o['scaling_factor']).to eq 25.2
          expect(o['objective_function_group']).to eq 7
        end
      end
    end

    it 'should write a json' do
      @excel.save_analysis
      expect(File.exist?('spec/files/export/analysis/0_3_0_outputs.json')).to eq true
      expect(File.exist?('spec/files/export/analysis/0_3_0_outputs.zip')).to eq true

      # check the JSON
      h = JSON.parse(File.read('spec/files/export/analysis/0_3_0_outputs.json'))
      expect(h['analysis']['weather_file']).to be_a Hash
      expect(h['analysis']['weather_file']['path']).to match /partial_weather.*epw/
    end
  end

  context 'version 0.3.0 measure existence checks' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_3_0_measure_existence.xlsx')
    end

    it 'should process' do
      expect(@excel.process).to eq(true)

      model_name = @excel.models.first[:name]
      expect(model_name).to eq '0_3_0_outputs'
    end

    it 'should error out with missing measure information' do
      expect { @excel.save_analysis }.to raise_error /Measure in directory.*not contain a measure.rb.*$/
    end
  end

  context 'version 0.3.0 dynamic uuid assignments' do
    before(:all) do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_3_0_dynamic_uuids.xlsx')
    end

    it 'should process' do
      expect(@excel.process).to eq(true)

      model_uuid = @excel.models.first[:name]
      expect(model_uuid).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
    end

    it 'should error out with missing measure information' do
      @excel.save_analysis
      model_uuid = @excel.models.first[:name]
      expect(File.exist?("spec/files/export/analysis/#{model_uuid}.json")).to eq true
      expect(File.exist?("spec/files/export/analysis/#{model_uuid}.zip")).to eq true
    end
  end

  context 'version 0.3.3 and short display names' do
    before :all do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_3_3_short_names.xlsx')
    end

    it 'should process' do
      expect(@excel.process).to eq(true)

      model_uuid = @excel.models.first[:name]
      expect(model_uuid).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
    end

    it 'should process and save short display names' do
      @excel.save_analysis
      model_uuid = @excel.models.first[:name]
      expect(File.exist?("spec/files/export/analysis/#{model_uuid}.json")).to eq true
      expect(File.exist?("spec/files/export/analysis/#{model_uuid}.zip")).to eq true

      @excel.outputs['output_variables'].each do |o|
        expect(o['display_name_short']).to eq 'Site EUI' if o['name'] == 'standard_report_legacy.total_energy'
        expect(o['display_name_short']).to eq 'Natural Gas Heating Intensity' if o['name'] == 'standard_report_legacy.heating_natural_gas'
      end

      # Check the JSON
      j = JSON.parse(File.read("spec/files/export/analysis/#{model_uuid}.json"))
      expect(j['analysis']['output_variables'].first['display_name']).to eq 'Total Site Energy Intensity'
      expect(j['analysis']['output_variables'].first['display_name_short']).to eq 'Site EUI'
      expect(j['analysis']['problem']['workflow'][0]['variables'][0]['argument']['display_name']).to eq 'Orientation'
      expect(j['analysis']['problem']['workflow'][0]['variables'][0]['argument']['display_name_short']).to eq 'Shorter Display Name'
      expect(j['analysis']['problem']['workflow'][1]['arguments'][0]['display_name']).to eq 'unknown'
      expect(j['analysis']['problem']['workflow'][1]['arguments'][0]['display_name_short']).to eq 'un'
    end
  end

  context 'version 0.3.3 and short display names' do
    before :all do
      @excel = OpenStudio::Analysis::Translator::Excel.new('spec/files/0_3_5_multiple_measure_paths.xlsx')
    end

    it 'should process' do
      expect(@excel.process).to eq(true)
    end

    it 'should save the analysis' do
      @excel.save_analysis
      model_uuid = @excel.models.first[:name]

      expect(File.exist?("spec/files/export/analysis/#{model_uuid}.json")).to eq true
      expect(File.exist?("spec/files/export/analysis/#{model_uuid}.zip")).to eq true

      expect(@excel.aws_tags).to eq(['org=5500','nothing=else matters'])
    end
  end
end
