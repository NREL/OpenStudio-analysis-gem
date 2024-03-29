# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'spec_helper'

describe OpenStudio::Analysis::Formulation do
  it 'should create an analysis' do
    a = OpenStudio::Analysis.create('Name of an analysis')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name of an analysis'
    expect(a).to be_a OpenStudio::Analysis::Formulation
  end

  it 'should add measure paths' do
    expect(OpenStudio::Analysis.measure_paths).to eq ['./measures']
    OpenStudio::Analysis.measure_paths = ['a', 'b']
    expect(OpenStudio::Analysis.measure_paths).to eq ['a', 'b']

    # append a measure apth
    OpenStudio::Analysis.measure_paths << 'c'
    expect(OpenStudio::Analysis.measure_paths).to eq ['a', 'b', 'c']
  end

  it 'should have a workflow object' do
    a = OpenStudio::Analysis.create('workflow')
    expect(a.workflow).not_to be nil
  end

  it 'should load the workflow from a file' do
    OpenStudio::Analysis.measure_paths << 'spec/files/measures'
    a = OpenStudio::Analysis.create('workflow')
    file = File.join('spec/files/analysis/examples/medium_office_workflow.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
  end

  it 'should save a hash (version 1)' do
    OpenStudio::Analysis.measure_paths << 'spec/files/measures'
    a = OpenStudio::Analysis.create('workflow 2')
    file = File.join('spec/files/analysis/examples/medium_office_workflow.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
    h = a.to_hash
    # expect(h[:workflow].empty?).not_to eq true
  end

  it 'should read from windows fqp' do
    OpenStudio::Analysis.measure_paths << 'spec/files/measures'
    a = OpenStudio::Analysis.create('workflow 2')
    file = File.expand_path(File.join('spec/files/analysis/examples/medium_office_workflow.json'))
    file = file.tr('/', '\\') if Gem.win_platform?
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
  end

  it 'should create a save an empty analysis' do
    a = OpenStudio::Analysis.create('workflow')
    run_dir = 'spec/files/export/workflow'

    FileUtils.mkdir_p run_dir

    h = a.to_hash
    expect(h[:analysis][:problem][:analysis_type]).to eq nil
    expect(a.save("#{run_dir}/analysis.json")).to eq true
  end

  it 'should increment objective functions' do
    a = OpenStudio::Analysis.create('my analysis')

    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2',
      objective_function: true
    )

    expect(a.to_hash[:analysis][:output_variables].first[:objective_function_index]).to eq 0

    a.add_output(
      display_name: 'Another Output',
      name: 'standard_report_legacy.output_2',
      units: 'MJ/m2',
      objective_function: true
    )
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 1

    a.add_output(
      display_name: 'Another Output Not Objective Function',
      name: 'standard_report_legacy.output_3',
      units: 'MJ/m2',
      objective_function: false
    )

    a.add_output(
      display_name: 'Another Output 4',
      name: 'standard_report_legacy.output_4',
      units: 'MJ/m2',
      objective_function: true
    )
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 2
  end

  it 'should not change an output if objective function changes from true to false' do
    a = OpenStudio::Analysis.create('my analysis')

    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2',
      objective_function: true
    )

    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2',
      objective_function: false # this doesn't do anything
    )

    expect(a.to_hash[:analysis][:output_variables].size).to eq 1
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function]).to eq true
  end

  it 'should update an output with new values' do
    a = OpenStudio::Analysis.create('my analysis')

    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2'
    )
    expect(a.to_hash[:analysis][:output_variables].last[:units]).to eq 'MJ/m2'

    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'therms'
    )

    expect(a.to_hash[:analysis][:output_variables].size).to eq 1
    expect(a.to_hash[:analysis][:output_variables].last[:units]).to eq 'therms'
  end
  
  it 'should should have default display_name if not set' do
    a = OpenStudio::Analysis.create('my analysis')

    a.add_output(
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2'
    )
    expect(a.to_hash[:analysis][:output_variables].last[:display_name]).to eq a.to_hash[:analysis][:output_variables].last[:name]
  end
  
  it 'should create a new formulation' do
    a = OpenStudio::Analysis.create('my analysis')
    p = 'spec/files/measures/SetThermostatSchedules'

    a.workflow.add_measure_from_path('thermostat', 'thermostat', p)
    m = a.workflow.add_measure_from_path('thermostat_2', 'thermostat 2', p)

    d = {
      type: 'uniform',
      minimum: 5,
      maximum: 7,
      mean: 6.2
    }
    m.make_variable('cooling_sch', 'Change the cooling schedule', d)
    m.argument_value('heating_sch', 'some-string')

    expect(a.workflow.measures.size).to eq 2
    expect(a.workflow.measures[1].arguments[3][:value]).to eq 'some-string'
    expect(a.workflow.measures[1].variables[0][:uuid]).to match /[\w]{8}(-[\w]{4}){3}-[\w]{12}/

    a.analysis_type = 'single_run'
    a.algorithm.set_attribute('sample_method', 'all_variables')
    o = {
      display_name: 'Total Natural Gas',
      display_name_short: 'Total Natural Gas',
      metadata_id: nil,
      name: 'total_natural_gas',
      units: 'MJ/m2',
      objective_function: true,
      objective_function_index: 0,
      objective_function_target: 330.7,
      scaling_factor: nil,
      objective_function_group: nil
    }
    a.add_output(o)

    a.seed_model = 'spec/files/small_seed.osm'
    a.weather_file = 'spec/files/partial_weather.epw'
    
    # check value of download_zip
    expect(a.download_zip).to be true
    expect(a.to_hash[:analysis][:download_zip]).to match true
    a.download_zip = false
    expect(a.download_zip).to be false
    expect(a.to_hash[:analysis][:download_zip]).to match false
    expect { a.download_zip='bad' }.to raise_error(ArgumentError)
    
    # check value of download_reports
    expect(a.download_reports).to be true
    expect(a.to_hash[:analysis][:download_reports]).to match true
    a.download_reports = false
    expect(a.download_reports).to be false
    expect(a.to_hash[:analysis][:download_reports]).to match false
    expect { a.download_reports='bad' }.to raise_error(ArgumentError)
    
    # check value of download_osw
    expect(a.download_osw).to be true
    expect(a.to_hash[:analysis][:download_osw]).to match true
    a.download_osw = false
    expect(a.download_osw).to be false
    expect(a.to_hash[:analysis][:download_osw]).to match false
    expect { a.download_osw='bad' }.to raise_error(ArgumentError)
    
    # check value of download_osm
    expect(a.download_osm).to be true
    expect(a.to_hash[:analysis][:download_osm]).to match true
    a.download_osm = false
    expect(a.download_osm).to be false
    expect(a.to_hash[:analysis][:download_osm]).to match false
    expect { a.download_osm='bad' }.to raise_error(ArgumentError)

    # check value of cli_debug
    expect(a.cli_debug).to eq "--debug"
    expect(a.to_hash[:analysis][:cli_debug]).to eq "--debug"
    a.cli_debug = ""
    expect(a.cli_debug).to eq ""
    expect(a.to_hash[:analysis][:cli_debug]).to eq ""
    # we dont need to check for bad values since only the string --debug or '' are processed server side
    
    # check value of cli_verbose
    expect(a.cli_verbose).to eq "--verbose"
    expect(a.to_hash[:analysis][:cli_verbose]).to eq "--verbose"
    a.cli_verbose = ""
    expect(a.cli_verbose).to eq ""
    expect(a.to_hash[:analysis][:cli_verbose]).to eq ""
    # we dont need to check for bad values since only the string --verbose or '' are processed server side

    # check value of run_workflow_timeout
    expect(a.run_workflow_timeout).to eq 28800
    expect(a.to_hash[:analysis][:run_workflow_timeout]).to eq 28800
    a.run_workflow_timeout = 0
    expect(a.run_workflow_timeout).to eq 0
    expect(a.to_hash[:analysis][:run_workflow_timeout]).to eq 0
    expect { a.run_workflow_timeout='bad' }.to raise_error(ArgumentError)

    # check value of initialize_worker_timeout
    expect(a.initialize_worker_timeout).to eq 28800
    expect(a.to_hash[:analysis][:initialize_worker_timeout]).to eq 28800
    a.initialize_worker_timeout = 0
    expect(a.initialize_worker_timeout).to eq 0
    expect(a.to_hash[:analysis][:initialize_worker_timeout]).to eq 0
    expect { a.initialize_worker_timeout='bad' }.to raise_error(ArgumentError)

    # check value of upload_results_timeout
    expect(a.upload_results_timeout).to eq 28800
    expect(a.to_hash[:analysis][:upload_results_timeout]).to eq 28800
    a.upload_results_timeout = 0
    expect(a.upload_results_timeout).to eq 0
    expect(a.to_hash[:analysis][:upload_results_timeout]).to eq 0
    expect { a.upload_results_timeout='bad' }.to raise_error(ArgumentError)
    
    expect(a.seed_model.first).to eq 'spec/files/small_seed.osm'

    expect(a.to_hash[:analysis][:problem][:algorithm][:objective_functions]).to match ['total_natural_gas']
    expect(a.analysis_type).to eq 'single_run'

    dp_hash = a.to_static_data_point_hash
    expect(dp_hash[:data_point][:set_variable_values].values).to eq ['*No Change*']
  end

  it 'should load the urbanopt workflow from a file' do
    OpenStudio::Analysis.measure_paths << 'spec/files/measures'
    a = OpenStudio::Analysis.create('workflow')
    file = File.join('spec/files/workflow/UrbanOpt.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
  end
end
