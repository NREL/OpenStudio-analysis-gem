require 'spec_helper'

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
    @s.add('spec/files/worker_init/second_file.rb')

    expect(@s.size).to eq 2
    @s.each do |f|
      expect(f).to_not be nil
    end
  end

  it 'should remove existing items' do
    f = 'spec/files/worker_init/second_file.rb'
    @s.add(f)

    @s.clear
    expect(@s.size).to eq 0
  end

  it 'should only add existing files'

  it 'should add metadata data'

  it 'should add a directory' do
    @s.clear
    @s.add_files('spec/files/measures/**/*.rb', {d: 'new'})

    expect(@s.size).to eq 7
    expect(@s[0][:metadata][:d]).to eq 'new'
  end
end
