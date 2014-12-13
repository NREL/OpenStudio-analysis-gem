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

    puts @w.to_json

    puts
  end

  it 'should fix the path of the measure' do
    p = 'spec/files/measures/IncreaseInsulationRValueForRoofs/measure.rb'
    m = @w.add_measure_from_path('insulation', 'Increase Insulation', p)
    expect(m).to be_an OpenStudio::Analysis::WorkflowStep
    expect(m.measure_definition_directory).to eq 'spec/files/measures/IncreaseInsulationRValueForRoofs'
  end
end