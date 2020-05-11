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
