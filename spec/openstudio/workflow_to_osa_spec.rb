# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'spec_helper'
require 'json-schema'

describe 'Convert_an_OSW_to_OSA' do

  it 'should load an OSW from file and make OSA' do
    
    #check if file exists  
    osw_file = 'spec/files/osw_project/calibration_workflow.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name of an analysis')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name of an analysis'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    output = a.convert_osw(osw_file)
    expect(output).not_to be nil
    
    #expect measures to be in OSA workflow
    m = a.workflow.find_measure('add_monthly_json_utility_data')
    expect(m.argument_names).to eq ["__SKIP__", "json", "variable_name", "fuel_type", "consumption_unit", "data_key_name", "start_date", "end_date", "remove_existing_data", "set_runperiod"]

    #check arguments are of the correct type and value
    arg = m.arguments.find_all { |a| a[:name] == 'json' }
    expect(arg[0][:value].is_a? String).to be true
    expect(arg[0][:value]).to eq('../../../data/electric.json')
    
    #check argument is a Boolean and is True (default is false)
    arg = m.arguments.find_all { |a| a[:name] == 'remove_existing_data' }
    expect(arg[0][:value].class).to be TrueClass
    expect(arg[0][:value]).to eq(true)
    
    m = a.workflow.find_measure('add_monthly_json_utility_data_2')
    expect(m.argument_names).to eq ["__SKIP__", "json", "variable_name", "fuel_type", "consumption_unit", "data_key_name", "start_date", "end_date", "remove_existing_data", "set_runperiod"]
    
    #check arguments are of the correct type and value
    arg = m.arguments.find_all { |a| a[:name] == 'json' }
    expect(arg[0][:value].is_a? String).to be true
    expect(arg[0][:value]).to eq('../../../data/natural_gas.json')
    
    m = a.workflow.find_measure('general_calibration_measure_percent_change')
    expect(m.argument_names).to eq ["__SKIP__", "space_type", "space", "lights_perc_change", "luminaire_perc_change", "ElectricEquipment_perc_change", "GasEquipment_perc_change", "OtherEquipment_perc_change", "people_perc_change", "mass_perc_change", "infil_perc_change", "vent_perc_change"]
    
    expect(a.workflow.measures.size).to eq 4
    expect(a.workflow.items.size).to eq 4

    expect(a.workflow.all_variables.size).to eq 0
    
    #make a variable
    v = {
      type: 'uniform',
      minimum: 0.5,
      maximum: 20,
      mean: 10
    }
    out = m.make_variable('lights_perc_change', 'Lights Percent Change', v)
    expect(out).to be true
    expect(m.variables.size).to be 1

    #make another variable
    out = m.make_variable('ElectricEquipment_perc_change', 'Electric Equipment Percent Change', v)
    expect(out).to be true
    expect(m.variables.size).to be 2

    #expect variable type to be uniform
    expect(m.variables[0][:type]).to eq('uniform')
    expect(m.variables[0][:minimum]).to eq(0.5)
    expect(m.variables[0][:maximum]).to eq(20)
    expect(m.variables[0][:mode]).to eq(10)
    expect(m.variables[0][:step_size]).to be nil
    expect(m.variables[0][:standard_deviation]).to be nil
    #expect variable uncertainty_description to be nil since it hasnt been created yet by .to_hash 
    expect(m.variables[0][:uncertainty_description]).to be nil
    
    #call .to_hash to populate uncertainty_description in the OSA
    a.to_hash
    #expect variable type to NOT be nil, still uniform, since it shouldnt be deleted now
    expect(m.variables[0][:type]).to eq('uniform')
    expect(m.variables[0][:minimum]).to eq(0.5)
    expect(m.variables[0][:maximum]).to eq(20)
    expect(m.variables[0][:mode]).to eq(10)
    expect(m.variables[0][:step_size]).to be nil
    expect(m.variables[0][:standard_deviation]).to be nil
    #expect variable uncertainty_description to still be uniform after a call to .to_hash
    expect(m.variables[0][:uncertainty_description]).to be nil
    
    #call .to_hash AGAIN to populate uncertainty_description in the OSA
    a.to_hash
    #expect variable type to NOT be nil, still uniform, since it shouldnt be deleted now
    expect(m.variables[0][:type]).to eq('uniform')
    expect(m.variables[0][:minimum]).to eq(0.5)
    expect(m.variables[0][:maximum]).to eq(20)
    expect(m.variables[0][:mode]).to eq(10)
    expect(m.variables[0][:step_size]).to be nil
    expect(m.variables[0][:standard_deviation]).to be nil
    #expect variable uncertainty_description to still be uniform after a call to .to_hash
    expect(m.variables[0][:uncertainty_description]).to be nil
            
    #remove the first one
    expect(m.remove_variable('lights_perc_change')).to be true
    expect(m.variables.size).to be 1
    
    #remove bad one
    expect(m.remove_variable('bad value')).to be false
    expect(m.variables.size).to be 1
    
    #check arguments are of the correct type and value
    arg = m.arguments.find_all { |a| a[:name] == 'vent_perc_change' }
    expect(arg[0][:value].is_a? Float).to be true
    expect(arg[0][:value]).to eq(10.0)
    
    #check luminaire_perc_change did not change since its not in OSW
    arg = m.arguments.find_all { |a| a[:name] == 'luminaire_perc_change' }
    expect(arg[0][:value].is_a? Float).to be true
    expect(arg[0][:value]).to eq(0.0)
    
    #add output variable
    a.add_output(
          display_name: 'electricity_consumption_cvrmse',
          name: 'calibration_reports_enhanced.electricity_consumption_cvrmse',
          units: '%',
          objective_function: true
        )
    expect(a.to_hash[:analysis][:output_variables].size).to eq 1
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_group]).to eq 1
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 0
    
    a.add_output(
          display_name: 'electricity_consumption_nmbe',
          name: 'calibration_reports_enhanced.electricity_consumption_nmbe',
          units: '%',
          objective_function: true,
          objective_function_group: 2
        )
    expect(a.to_hash[:analysis][:output_variables].size).to eq 2
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_group]).to eq 2
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 1
    
    a.add_output(
          display_name: 'natural_gas_consumption_cvrmse',
          name: 'calibration_reports_enhanced.natural_gas_consumption_cvrmse',
          units: '%',
          objective_function: true
        )
    expect(a.to_hash[:analysis][:output_variables].size).to eq 3
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_group]).to eq 1
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 2
    
    #change to objective_function_group 3
    a.add_output(
          display_name: 'natural_gas_consumption_cvrmse',
          name: 'calibration_reports_enhanced.natural_gas_consumption_cvrmse',
          units: '%',
          objective_function: true,
          objective_function_group: 3
        )
    expect(a.to_hash[:analysis][:output_variables].size).to eq 3
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_group]).to eq 3
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 2
    
    #add another objective_function
    a.add_output(
          display_name: 'natural_gas_consumption_nmbe',
          name: 'calibration_reports_enhanced.natural_gas_consumption_nmbe',
          units: '%',
          objective_function: true,
          objective_function_group: 4
        )
    expect(a.to_hash[:analysis][:output_variables].size).to eq 4
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_group]).to eq 4
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 3
    
    #add a non-objective_function output
    a.add_output(
          display_name: 'electricity_ip',
          name: 'openstudio_results.electricity_ip',
          units: '%',
        )   
    expect(a.to_hash[:analysis][:output_variables].size).to eq 5
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_group]).to eq nil
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq nil
    
    #make sure [:algorithm][:objective_function] match the objective_functions from outputs
    #this is method in analysis/formulation.rb .to_hash
    ofs = a.outputs.map { |i| i[:name] if i[:objective_function] }.compact
    expect(a.algorithm[:objective_functions]).to match ofs

    #expect analysis_type = single_run which is default in convert_osw
    expect(a.analysis_type).to match 'single_run'
    #change analysis_type
    expect(a.analysis_type = 'nsga_nrel').to match 'nsga_nrel'  
    expect(a.analysis_type = 'single_run').to match 'single_run'      
    #try setting bad analysis_type
    expect { a.analysis_type = 'single_run2' }.to raise_error(RuntimeError, /Invalid analysis type./)

    #add data_point initialization script
    f = 'spec/files/osw_project/scripts/script.sh'
    expect(a.server_scripts.add(f, ['one', 'two'])).to be true
    # add analysis finalization script
    expect(a.server_scripts.add(f, ['three', 'four'], 'finalization', 'analysis')).to be true
    #TODO server_scripts are not in OSA right now since its not manditory
    
    #validate OSA against schema
    File.write('spec/files/osw_project/analysis.json',JSON.pretty_generate(a.to_hash))
    osa_schema = JSON.parse(File.read('spec/schema/osa_server_schema.json'), symbolize_names: true)
    errors = JSON::Validator.fully_validate(osa_schema, a.to_hash)
    expect(errors.empty?).to eq(true), "OSA is not valid, #{errors}"
    
    #Add directory Data to libraries, contains calibration data jsons.  would get unzipped to /lib/folder on server
    expect(a.libraries.add('spec/files/osw_project/Data', {library_name: 'calibration_data'})).to eq(true)
    expect(a.libraries.size).to eq(1)
    expect(a.libraries[0]).to eq({:file=>"spec/files/osw_project/Data", :metadata=>{:library_name=>"calibration_data"}})
    
    #make project zip file
    a.save_osa_zip('spec/files/osw_project/analysis.zip')
    # Open the zip file
    Zip::File.open('spec/files/osw_project/analysis.zip') do |zip_file|
      # Verify that the expected files are present in the zip file
      expect(zip_file.find_entry("seeds/example_model.osm")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.epw")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.stat")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.ddy")).to be_truthy
      expect(zip_file.find_entry("measures/AddMonthlyJSONUtilityData/measure.rb")).to be_truthy
      expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/measure.rb")).to be_truthy
      expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/resources/report.html.in")).to be_truthy
      expect(zip_file.find_entry("measures/GeneralCalibrationMeasurePercentChange/measure.rb")).to be_truthy
      expect(zip_file.find_entry("lib/calibration_data/electric.json")).to be_truthy
      expect(zip_file.find_entry("lib/calibration_data/natural_gas.json")).to be_truthy
      expect(zip_file.find_entry("scripts/data_point/initialization.sh")).to be_truthy
      expect(zip_file.find_entry("scripts/data_point/initialization.args")).to be_truthy
      expect(zip_file.find_entry("scripts/analysis/finalization.sh")).to be_truthy
      expect(zip_file.find_entry("scripts/analysis/finalization.args")).to be_truthy
      expect(zip_file.find_entry("weather/test1.epw")).to be_nil
      expect(zip_file.find_entry("weather/test1.stat")).to be_nil
      expect(zip_file.find_entry("weather/test1.ddy")).to be_nil
      expect(zip_file.find_entry("weather/test2.epw")).to be_nil
      expect(zip_file.find_entry("weather/test2.stat")).to be_nil
    end
  end

  it 'should handle measure paths in OSW' do
    #measure paths are in OSW, but relative to /spec dir
    
    #check if file exists  
    osw_file = 'spec/files/osw_project/measure_paths_osw.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    output = a.convert_osw(osw_file)
    expect(output).not_to be nil
    
  end
  
  it 'should handle duplicate measure paths in OSW' do
    #measure paths are in OSW, but relative to /spec dir
    #paths are also manually input as well
    
    #check if file exists  
    osw_file = 'spec/files/osw_project/measure_paths_osw.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    paths = [
    'spec/files/measures',
    'spec/files/measures_second_path'
    ]
    puts "paths = #{paths}"
    output = a.convert_osw(osw_file, paths)
    expect(output).not_to be nil
    
  end
  
  it 'should handle multiple measure paths' do
    
    #check if file exists  
    osw_file = 'spec/files/osw_project/diff_measure_paths.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    paths = [
    'spec/files/measures',
    'spec/files/measures_second_path'
    ]
    puts "paths = #{paths}"
    output = a.convert_osw(osw_file, paths)
    expect(output).not_to be nil
    
  end
  
  it 'should raise missing measure arguments in osw' do
    
    #check if file exists  
    osw_file = 'spec/files/osw_project/missing_argument.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    paths = [
    'spec/files/measures',
    'spec/files/measures_second_path'
    ]
    puts "paths = #{paths}"
    expect {output = a.convert_osw(osw_file, paths)}.to raise_error(RuntimeError, /measure measure_in_another_dir step has no arguments: {:measure_dir_name=>"measure_in_another_dir"}/)
    
  end
  
  it 'should handle empty paths' do
    
    #check if file exists  
    osw_file = 'spec/files/osw_project/diff_measure_paths.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    paths = [
    'spec/files/measures',
    '',
    'spec/files/measures_second_path'
    ]
    puts "paths = #{paths}"
    output = a.convert_osw(osw_file, paths)
    expect(output).not_to be nil
    
  end
  
  it 'should raise if measure not found' do
    
    #check if file exists  
    osw_file = 'spec/files/osw_project/diff_measure_paths.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    paths = [
    'spec/files/measures',
    '',
    ]
    puts "paths = #{paths}"
    expect {a.convert_osw(osw_file, paths)}.to raise_error(RuntimeError, "measure measure_in_another_dir not found")
    
  end

  it 'should handle file_paths for seed/weather' do
    # This will test using :file_paths in OSW
    # :file_paths have no slashes in the path name
    # "file_paths": [
    # " seeds",
    # " weather"
    # ],
    #set working Dir to OSW so relative :file_paths in OSW are consistent
    Dir.chdir 'spec/files/osw_project'
    
    #check if file exists  
    osw_file = 'calibration_workflow_file_paths.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name of an analysis')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name of an analysis'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    output = a.convert_osw(osw_file)
    expect(output).not_to be nil
    
    #validate OSA against schema
    File.write('analysis2.json',JSON.pretty_generate(a.to_hash))
    #osa_schema = JSON.parse(File.read('spec/schema/osa_server_schema.json'), symbolize_names: true)
    #errors = JSON::Validator.fully_validate(osa_schema, a.to_hash)
    #expect(errors.empty?).to eq(true), "OSA is not valid, #{errors}"
    
    #make project zip file
    a.save_osa_zip('analysis2.zip')
    # Open the zip file
    Zip::File.open('analysis2.zip') do |zip_file|
      # Verify that the expected files are present in the zip file
      expect(zip_file.find_entry("seeds/example_model.osm")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.epw")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.stat")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.ddy")).to be_truthy
      expect(zip_file.find_entry("measures/AddMonthlyJSONUtilityData/measure.rb")).to be_truthy
      expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/measure.rb")).to be_truthy
      expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/resources/report.html.in")).to be_truthy
      expect(zip_file.find_entry("measures/GeneralCalibrationMeasurePercentChange/measure.rb")).to be_truthy
      expect(zip_file.find_entry("seeds/example_model_2.osm")).to be_nil
      expect(zip_file.find_entry("weather/test1.epw")).to be_nil
      expect(zip_file.find_entry("weather/test1.stat")).to be_nil
      expect(zip_file.find_entry("weather/test1.ddy")).to be_nil
      expect(zip_file.find_entry("weather/test2.epw")).to be_nil
      expect(zip_file.find_entry("weather/test2.stat")).to be_nil
    end
    
    #make project zip file with all weather files
    a.save_osa_zip('analysis3.zip', all_weather_files = true, all_seed_files = true)
    # Open the zip file
    Zip::File.open('analysis3.zip') do |zip_file|
      # Verify that the expected files are present in the zip file
      expect(zip_file.find_entry("seeds/example_model.osm")).to be_truthy
      expect(zip_file.find_entry("seeds/example_model_2.osm")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.epw")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.stat")).to be_truthy
      expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.ddy")).to be_truthy
      expect(zip_file.find_entry("measures/AddMonthlyJSONUtilityData/measure.rb")).to be_truthy
      expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/measure.rb")).to be_truthy
      expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/resources/report.html.in")).to be_truthy
      expect(zip_file.find_entry("measures/GeneralCalibrationMeasurePercentChange/measure.rb")).to be_truthy
      expect(zip_file.find_entry("weather/test1.epw")).to be_truthy
      expect(zip_file.find_entry("weather/test1.stat")).to be_truthy
      expect(zip_file.find_entry("weather/test1.ddy")).to be_truthy
      expect(zip_file.find_entry("weather/test2.epw")).to be_truthy
      expect(zip_file.find_entry("weather/test2.stat")).to be_truthy
    end
    
    #reset working dir
    Dir.chdir '../../..'
  end

  it 'should handle being in subdirectory for file_paths' do
    # This will test being in a subdirectory, with OSW at a higher level and
    # seeds and weather in other subdirectories
    # "file_paths": [
    # "../seeds",
    # "../weather"
    # ],
    
    #set working Dir to OSW so relative :file_paths in OSW are consistent
    Dir.chdir 'spec/files/osw_project/temp'
    
    #check if file exists  
    osw_file = '../changed_file_paths.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name of an analysis')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name of an analysis'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    output = a.convert_osw(osw_file)
    expect(output).not_to be nil
    
    #validate OSA against schema
    File.write('analysis.json',JSON.pretty_generate(a.to_hash))
    #osa_schema = JSON.parse(File.read('spec/schema/osa_server_schema.json'), symbolize_names: true)
    #errors = JSON::Validator.fully_validate(osa_schema, a.to_hash)
    #expect(errors.empty?).to eq(true), "OSA is not valid, #{errors}"
    
    #make project zip file
    a.save_osa_zip('analysis.zip')
    # Open the zip file
    Zip::File.open('analysis.zip') do |zip_file|
    # Verify that the expected files are present in the zip file
    expect(zip_file.find_entry("seeds/example_model.osm")).to be_truthy
    expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.epw")).to be_truthy
    expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.stat")).to be_truthy
    expect(zip_file.find_entry("measures/AddMonthlyJSONUtilityData/measure.rb")).to be_truthy
    expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/measure.rb")).to be_truthy
    expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/resources/report.html.in")).to be_truthy
    expect(zip_file.find_entry("measures/GeneralCalibrationMeasurePercentChange/measure.rb")).to be_truthy
    end
    
    #reset working dir
    Dir.chdir '../../../..'
  end
  
  it 'should handle being in subdirectory for file_paths with windows style', :if => RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/ do
    # This will test being in a subdirectory, with OSW at a higher level and
    # windows style paths to seeds and weather in other subdirectories
    # "file_paths": [
    # "..\\seeds",
    # "..\\weather"
    # ],
    
    #set working Dir to OSW so relative :file_paths in OSW are consistent
    Dir.chdir 'spec/files/osw_project/temp'
    
    #check if file exists  
    osw_file = '../changed_file_paths_windows.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name of an analysis')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name of an analysis'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    output = a.convert_osw(osw_file)
    expect(output).not_to be nil
    
    #validate OSA against schema
    File.write('analysis2.json',JSON.pretty_generate(a.to_hash))
    #osa_schema = JSON.parse(File.read('spec/schema/osa_server_schema.json'), symbolize_names: true)
    #errors = JSON::Validator.fully_validate(osa_schema, a.to_hash)
    #expect(errors.empty?).to eq(true), "OSA is not valid, #{errors}"
    
    #make project zip file
    a.save_osa_zip('analysis2.zip')
    # Open the zip file
    Zip::File.open('analysis2.zip') do |zip_file|
    # Verify that the expected files are present in the zip file
    expect(zip_file.find_entry("seeds/example_model.osm")).to be_truthy
    expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.epw")).to be_truthy
    expect(zip_file.find_entry("weather/USA_CO_Golden-NREL.724666_TMY3.stat")).to be_truthy
    expect(zip_file.find_entry("measures/AddMonthlyJSONUtilityData/measure.rb")).to be_truthy
    expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/measure.rb")).to be_truthy
    expect(zip_file.find_entry("measures/CalibrationReportsEnhanced/resources/report.html.in")).to be_truthy
    expect(zip_file.find_entry("measures/GeneralCalibrationMeasurePercentChange/measure.rb")).to be_truthy
    end
    
    #reset working dir
    Dir.chdir '../../../..'
  end
    
end
