# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

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
    expect(epw.data_type).to eq 'TMY3'
    expect(epw.wmo).to eq 725650
    expect(epw.lat).to eq 39.83
    expect(epw.lon).to eq -104.65
    expect(epw.gmt).to eq -7.0
    expect(epw.elevation).to eq 1650.0

    expect(epw.header_data.size).to eq 7
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
