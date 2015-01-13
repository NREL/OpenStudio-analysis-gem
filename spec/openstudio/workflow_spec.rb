require 'spec_helper'

describe OpenStudio::Analysis::Workflow do
  before :all do
    @w = OpenStudio::Analysis::Workflow.new
  end

  it 'should create a workflow' do
    expect(@w).not_to be nil
    expect(@w).to be_a OpenStudio::Analysis::Workflow
  end

  it 'should add a measure' do
    p = 'spec/files/measures/IncreaseInsulationRValueForRoofs'
    expect(@w.add_measure_from_path('insulation', 'Increase Insulation', p)).to be_an OpenStudio::Analysis::WorkflowStep

    p = 'spec/files/measures/ActualMeasureNoJson'
    FileUtils.remove "#{p}/measure.json" if File.exist? "#{p}/measure.json"
    m = @w.add_measure_from_path('a_measure', 'Actual Measure', p)
    expect(m).to be_a OpenStudio::Analysis::WorkflowStep
    expect(m.measure_definition_class_name).to eq 'RotateBuilding'
  end

  it 'should fix the path of the measure' do
    p = 'spec/files/measures/IncreaseInsulationRValueForRoofs/measure.rb'
    m = @w.add_measure_from_path('insulation', 'Increase Insulation', p)
    expect(m).to be_an OpenStudio::Analysis::WorkflowStep
    expect(m.measure_definition_directory).to eq './measures/IncreaseInsulationRValueForRoofs'
    expect(m.measure_definition_directory_local).to eq 'spec/files/measures/IncreaseInsulationRValueForRoofs'
  end

  it 'should clear out a workflow' do
    p = 'spec/files/measures/SetThermostatSchedules'
    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat 2', 'thermostat 2', p)

    expect(@w.items.size).to be > 1
    @w.clear
    expect(@w.items.size).to eq 0

    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat 2', 'thermostat 2', p)
    expect(@w.items.size).to eq 2
  end

  it 'should find a workflow step' do
    @w.clear

    p = 'spec/files/measures/SetThermostatSchedules'
    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat_2', 'thermostat 2', p)

    m = @w.find_measure('thermostat_2')
    expect(m).not_to be nil
    expect(m).to be_a OpenStudio::Analysis::WorkflowStep
    expect(m.name).to eq 'thermostat_2'
  end

  it 'should find a workflow step and make a variable' do
    @w.clear

    p = 'spec/files/measures/SetThermostatSchedules'
    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat_2', 'thermostat 2', p)

    m = @w.find_measure('thermostat_2')
    expect(m.argument_names).to eq %w(zones cooling_sch heating_sch material_cost)

    d = {
      type: 'uniform',
      minimum: 5,
      maximum: 7,
      mean: 6.2
    }
    m.make_variable('cooling_sch', 'Change the cooling schedule', d)

    d = {
      type: 'uniform',
      minimum: 5,
      maximum: 7,
      mean: 6.2
    }
    m.make_variable('heating_sch', 'Change the heating schedule', d)

    expect(@w.measures.size).to eq 2
    expect(@w.items.size).to eq 2
    expect(@w.items.size).to eq 2

    expect(@w.all_variables.size).to eq 2
  end
end
