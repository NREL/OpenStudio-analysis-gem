require 'spec_helper'

describe OpenStudio::Analysis::Workflow do
  before :all do

  end

  it 'should create aw workflow' do
    a = OpenStudio::Analysis::Workflow.new
    expect(a).not_to be nil
    expect(a).to be_a OpenStudio::Analysis::Workflow
  end


end