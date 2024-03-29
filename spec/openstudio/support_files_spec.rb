# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require_relative './../spec_helper'

describe OpenStudio::Analysis::SupportFiles do
  before :all do
    @s = OpenStudio::Analysis::SupportFiles.new
    expect(@s).to be_a OpenStudio::Analysis::SupportFiles
  end

  it 'should add files' do
    f = 'spec/files/worker_init/first_file.rb'
    @s.add(f)

    expect(@s.size).to eq 1
    expect(@s.files.first[:file]).to eq f

    # add some other items
    @s.add('spec/files/worker_init/second_file.sh')

    expect(@s.size).to eq 2
    @s.each do |f|
      expect(f).to_not be nil
    end
  end

  it 'should remove existing items' do
    f = 'spec/files/worker_init/second_file.sh'
    @s.add(f)

    @s.clear
    expect(@s.size).to eq 0
  end

  it 'should only add existing files' do
    f = 'spec/files/worker_init/second_file.sh'
    @s.add(f)
    @s.add(f)

    expect(@s.size).to eq 1

    f = 'non-existent.rb'
    expect { @s.add(f) }.to raise_error /Path or file does not exist and cannot be added.*/
  end

  it 'should add metadata data' do
  end

  it 'should add a directory' do
    @s.clear
    @s.add_files('spec/files/measures/**/*.rb', d: 'new')

    expect(@s.size).to eq 10
    expect(@s[0][:metadata][:d]).to eq 'new'
  end
end
