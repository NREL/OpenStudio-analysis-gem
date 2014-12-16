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
end