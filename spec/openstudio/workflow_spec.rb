require 'spec_helper'

describe OpenStudio::Analysis::Workflow do
  before :all do
    @a = OpenStudio::Analysis::Workflow.new
  end

  it 'should create a workflow' do
    expect(@a).not_to be nil
    expect(@a).to be_a OpenStudio::Analysis::Workflow
  end

  it 'should add a measure' do
    p = 'spec/files/measures/IncreaseInsulationRValueForRoofs'
    expect(@a.add_measure_from_path(p)).to be_a Hash

    p = 'spec/files/measures/ActualMeasureNoJson'
    FileUtils.remove "#{p}/measure.json" if File.exist? "#{p}/measure.json"
    m = @a.add_measure_from_path(p)

    puts @a.measures
  end
end