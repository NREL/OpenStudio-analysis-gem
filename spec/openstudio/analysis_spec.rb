require 'spec_helper'

describe OpenStudio::Analysis::Formulation do
  before :all do


  end

  it 'should create an analysis' do
    a = OpenStudio::Analysis.create("Name of an analysis")
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
    file = File.join('spec/files/analysis/medium_office.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
  end

  it 'should save a hash (version 1)' do
    a = OpenStudio::Analysis.create('workflow 2')
    file = File.join('spec/files/analysis/medium_office.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
    h = a.to_hash
    #expect(h[:workflow].empty?).not_to eq true
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

    #a.workflow.
    #a.workflow.add_measure()

    expect(a.workflow.measures.size).to eq 2
    puts JSON.pretty_generate(a.to_hash)


  end
end