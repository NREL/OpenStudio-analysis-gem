# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2023, Alliance for Sustainable Energy, LLC.
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

 end 