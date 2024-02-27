# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require_relative './../spec_helper'

describe OpenStudio::Analysis::ServerScripts do
  before :all do
    @s = OpenStudio::Analysis::ServerScripts.new
    expect(@s).to be_a OpenStudio::Analysis::ServerScripts
  end

  it 'should add files' do
    f = 'spec/files/osw_project/scripts/script.sh'
    expect(@s.add(f, ['one', 'two'])).to be true

    expect(@s.size).to eq 1
    expect(File.exists?(@s.files.first[:file])).to be true

    expect(@s[0][:init_or_final]).to eq 'initialization'
    expect(@s[0][:server_or_data_point]).to eq 'data_point'
    
    # add another items
    expect(@s.add(f, ['three', 'four'], 'finalization', 'analysis')).to be true

    expect(@s.size).to eq 2
    @s.each do |f|
      expect(f).to_not be nil
    end
    
    @s.each_with_index do |file, index|
      expect(File.basename(file[:file])).to eq 'script.sh'
    end
    
    @s.clear
    expect(@s.size).to eq 0
  end

  it 'should add a Gemfile' do
    # test with an entire analysis workflow
    osa = OpenStudio::Analysis.create('Name of an analysis')
    
    osa.gem_files.add('spec/files/gem_files/Gemfile')
    osa.gem_files.add('spec/files/gem_files/openstudio-gems.gemspec')

    os_json = osa.to_hash
    puts JSON.pretty_generate(os_json)
    expect(os_json[:analysis][:gemfile]).to be true

    # not sure how to test with the zip...
  end

end 