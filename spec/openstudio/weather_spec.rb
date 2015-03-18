require 'spec_helper'

describe OpenStudio::Weather::Epw do
  before :all do
    @s = OpenStudio::Analysis::SupportFiles.new
    expect(@s).to be_a OpenStudio::Analysis::SupportFiles
  end

  it 'should process the header of a weather file' do
    epw = OpenStudio::Weather::Epw.load('spec/files/partial_weather.epw')
    expect(epw.valid?).to be true
    expect(epw.city).to eq 'Denver Intl Ap'
    expect(epw.state).to eq 'CO'
    expect(epw.country).to eq 'USA'
    expect(epw.file_type).to eq 'TMY3'
    expect(epw.wmo).to eq '725650'
    expect(epw.lat).to eq 39.83
    expect(epw.lon).to eq -104.65
    expect(epw.gmt).to eq -7.0
    expect(epw.elevation).to eq 1650.0

    expect(epw.header_data.size).to eq 8
    expect(epw.weather_data.size).to eq 24
  end

  it 'should read and write the weather file' do
    o = 'spec/files/partial_weather.epw'
    epw = OpenStudio::Weather::Epw.load(o)
    f = 'spec/files/export/weather/weather_out.epw'
    File.delete(f) if File.exist? f
    expect(epw.save_as(f)).to eq true
    expect(File.exist?(f)).to eq true
    expect(File.size(o)).to eq File.size(f)
  end

  it 'should append weather data' do
    o = 'spec/files/partial_weather.epw'
    epw = OpenStudio::Weather::Epw.load(o)

    epw.append_weather_data(o)

    f = 'spec/files/export/weather/weather_out_appended.epw'
    epw.save_as(f)
  end

end
