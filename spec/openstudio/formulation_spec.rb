require 'spec_helper'

describe OpenStudio::Analysis::Formulation do
  it 'should create an analysis' do
    a = OpenStudio::Analysis.create('Name of an analysis')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name of an analysis'
    expect(a).to be_a OpenStudio::Analysis::Formulation
  end

  it 'should have a workflow object' do
    a = OpenStudio::Analysis.create('workflow')
    expect(a.workflow).not_to be nil
  end

  it 'should load the workflow from a file' do
    a = OpenStudio::Analysis.create('workflow')
    file = File.join('spec/files/analysis/examples/medium_office_example.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
  end

  it 'should save a hash (version 1)' do
    a = OpenStudio::Analysis.create('workflow 2')
    file = File.join('spec/files/analysis/examples/medium_office_example.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
    h = a.to_hash
    # expect(h[:workflow].empty?).not_to eq true
  end

  it 'should create a save an empty analysis' do
    a = OpenStudio::Analysis.create('workflow')
    run_dir = 'spec/files/export/workflow'

    FileUtils.mkdir_p run_dir

    h = a.to_hash
    expect(h[:analysis][:problem][:analysis_type]).to eq nil
    expect(a.save "#{run_dir}/analysis.json").to eq true
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
    expect(a.workflow.measures[1].arguments[2][:value]).to eq 'some-string'
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

    a.seed_model('spec/files/small_seed.osm')
    a.weather_file('spec/files/partial_weather.epw')

    expect(a.to_hash[:analysis][:problem][:algorithm][:objective_functions]).to match ['total_natural_gas']
    expect(a.analysis_type).to eq 'single_run'

    dp_hash = a.to_static_data_point_hash
    expect(dp_hash[:data_point][:set_variable_values].values).to eq ['*No Change*']
  end
end
