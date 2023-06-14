# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'spec_helper'

describe OpenStudio::Analysis::WorkflowStep do
  it 'should create a workflow' do
    s = OpenStudio::Analysis::WorkflowStep.new
    expect(s).not_to be nil
    expect(s).to be_a OpenStudio::Analysis::WorkflowStep
  end

  it 'should add a measure' do
    # convert XML to hash
    xml_file = 'spec/files/measures/IncreaseInsulationRValueForRoofs/measure.xml'
    h = parse_measure_xml(xml_file)
    s = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(s.name).to eq 'my_instance'
    expect(s.measure_definition_class_name).to eq 'IncreaseInsulationRValueForRoofs'
    expect(s.type).to eq 'ModelMeasure'
    expect(s.measure_definition_uuid).to eq '5fdd943e-ddd1-44b4-ae2d-94373fd71a78'
    expect(s.measure_definition_version_uuid).to eq 'c7800259-d525-4a08-b70d-dd261ca13353'
  end

  it 'should tag a discrete variable' do
    xml_file = 'spec/files/measures/SetThermostatSchedules/measure.xml'
    h = parse_measure_xml(xml_file)
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'discrete',
      minimum: 'low string',
      maximum: 'high string',
      mean: 'middle string',
      values: ['a', 'b', 'c', 'd'],
      weights: [0.25, 0.25, 0.25, 0.25]
    }
    r = measure.make_variable('cooling_sch', 'my variable', v)
    expect(r).to eq true
  end

  it 'should tag a continuous variable' do
    xml_file = 'spec/files/measures/SetThermostatSchedules/measure.xml'
    h = parse_measure_xml(xml_file)
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'triangle',
      minimum: 0.5,
      maximum: 20,
      mean: 10
    }
    o = {
      static_value: 24601
    }
    r = measure.make_variable('cooling_sch', 'my variable', v, o)

    h = measure.to_hash

    expect(h[:variables].first[:static_value]).to eq 24601
    expect(h[:variables].first.key?(:step_size)).to eq false

    expect(r).to eq true
  end

  it 'should tag a normal continuous variable' do
    xml_file = 'spec/files/measures/SetThermostatSchedules/measure.xml'
    h = parse_measure_xml(xml_file)

    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'normal',
      minimum: 0.5,
      maximum: 20,
      mean: 10,
      standard_deviation: 2
    }
    r = measure.make_variable('cooling_sch', 'my variable', v)

    h = measure.to_hash

    expect(h[:variables].first.key?(:step_size)).to eq false

    expect(r).to eq true
  end

  it 'should tag a uniform variable' do
    xml_file = 'spec/files/measures/SetThermostatSchedules/measure.xml'
    h = parse_measure_xml(xml_file)
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'uniform',
      minimum: 0.5,
      maximum: 20,
      mean: 10
    }
    r = measure.make_variable('cooling_sch', 'my variable', v)

    h = measure.to_hash

    # puts JSON.pretty_generate(h)
    expect(h[:variables].first.key?(:step_size)).to eq false

    expect(r).to eq true
  end
end
