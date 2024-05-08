# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

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
  end

  it 'should parse arguments' do
    p = 'spec/files/measures/ActualMeasureNoJson'
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

  it 'should find move a workflow step to after a named step' do
    @w.clear

    p = 'spec/files/measures/SetThermostatSchedules'
    m1 = @w.add_measure_from_path('thermostat_1', 'thermostat', p)
    m2 = @w.add_measure_from_path('thermostat_2', 'thermostat 2', p)
    m3 = @w.add_measure_from_path('thermostat_3', 'thermostat 3', p)
    m4 = @w.add_measure_from_path('thermostat_4', 'thermostat 4', p)

    measure_names = @w.measures.map(&:name)
    expect(measure_names).to eq ['thermostat_1', 'thermostat_2', 'thermostat_3', 'thermostat_4']
    # find the index where the measure is in the workflow
    @w.move_measure_after('thermostat_4', 'thermostat_2')
    # @w.measures.insert(@w.measures.index(m2), @w.measures.delete_at(@w.measures.index(m4)))
    # should return thermostat, thermostat_2, thermostat_4, thermostat_3

    measure_names = @w.measures.map(&:name)
    expect(measure_names).to eq ['thermostat_1', 'thermostat_2', 'thermostat_4',  'thermostat_3']

    # now move it to the end
    @w.move_measure_after('thermostat_4', 'thermostat_3')
    measure_names = @w.measures.map(&:name)
    expect(measure_names).to eq ['thermostat_1', 'thermostat_2', 'thermostat_3', 'thermostat_4']
    
    # now move it to the beginning -- do not say the after measure
    @w.move_measure_after('thermostat_4')
    measure_names = @w.measures.map(&:name)
    expect(measure_names).to eq ['thermostat_4', 'thermostat_1', 'thermostat_2', 'thermostat_3']
    
    # TODO: verify that errors are thrown when measures do not exist
    
  end



  it 'should find a workflow step and make a variable' do
    @w.clear

    p = 'spec/files/measures/SetThermostatSchedules'
    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat_2', 'thermostat 2', p)

    m = @w.find_measure('thermostat_2')
    expect(m.argument_names).to eq ['__SKIP__', 'zones', 'cooling_sch', 'heating_sch', 'material_cost']

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
