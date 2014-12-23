require 'spec_helper'

describe OpenStudio::Analysis::WorkflowStep do
  it 'should create a workflow' do
    s = OpenStudio::Analysis::WorkflowStep.new
    expect(s).not_to be nil
    expect(s).to be_a OpenStudio::Analysis::WorkflowStep
  end

  it 'should add a measure' do
    h = 'spec/files/measures/IncreaseInsulationRValueForRoofs/measure.json'
    s = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
        'my_instance',
        'my instance display name',
        h,
        JSON.parse(File.read(h), symbolize_names: true))
    puts s
  end

  it 'should tag a discrete variable' do
    h = 'spec/files/measures/SetThermostatSchedules/measure.json'
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
        'my_instance',
        'my instance display name',
        h,
        JSON.parse(File.read(h), symbolize_names: true))

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'discrete',
      minimum: 'low string',
      maximum: 'high string',
      mean: 'middle string',
      values: %w(a b c d),
      weights: [0.25, 0.25, 0.25, 0.25]
    }
    r = measure.make_variable('cooling_sch', 'my variable', v)
    expect(r).to eq true
  end

  it 'should tag a continuous variable' do
    h = 'spec/files/measures/SetThermostatSchedules/measure.json'
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
        'my_instance',
        'my instance display name',
        h,
        JSON.parse(File.read(h), symbolize_names: true))

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'triangle',
      minimum: 0.5,
      maximum: 20,
      mean: 10,
      static_value: 24601
    }
    r = measure.make_variable('cooling_sch', 'my variable', v)

    h = measure.to_hash

    expect(h[:variables].first[:static_value]).to eq 24601
    expect(h[:variables].first.key?(:step_size)).to eq false

    expect(r).to eq true
  end

  it 'should tag a normal continuous variable' do
    h = 'spec/files/measures/SetThermostatSchedules/measure.json'
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
        'my_instance',
        'my instance display name',
        h,
        JSON.parse(File.read(h), symbolize_names: true))

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
    h = 'spec/files/measures/SetThermostatSchedules/measure.json'
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
        'my_instance',
        'my instance display name',
        h,
        JSON.parse(File.read(h), symbolize_names: true))

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
