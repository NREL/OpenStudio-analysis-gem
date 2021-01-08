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

describe OpenStudio::Analysis::Translator::Workflow do
  before :all do
    clean_dir = File.expand_path 'spec/files/workflow/datapoints'

    if Dir.exist? clean_dir
      FileUtils.rm_rf clean_dir
    end
  end

  context 'read in the osa' do
    let(:osa_path) { File.expand_path 'analysis.osa' }

    before(:each) do
      Dir.chdir 'spec/files/workflow'
      @translator = OpenStudio::Analysis::Translator::Workflow.new(osa_path)
    end

    after(:each) do
      Dir.chdir '../../..'
    end

    it 'should find and load the osa' do
      expect(@translator).not_to be_nil
    end

    it 'should load the analysis' do
      expect(@translator.osa.class).to eq(Hash)
      expect(@translator.osa).not_to eq({})
    end

    it 'should not have measure_paths and ../lib in file paths' do
      expect(@translator.file_paths).to eq(['../lib'])
      expect(@translator.measure_paths).to eq([])
    end

    it 'should have steps' do
      expect(@translator.steps.class).to eq(Array)
      expect(@translator.steps).not_to eq([])
      @translator.steps.each do |step|
        expect(step.class).to eq(Hash)
        expect(step).not_to eq({})
      end
    end
  end

  context 'read in the urbanopt osa' do
    let(:osa_path) { File.expand_path 'UrbanOpt.json' }

    before(:each) do
      Dir.chdir 'spec/files/workflow'
      @translator = OpenStudio::Analysis::Translator::Workflow.new(osa_path)
    end

    after(:each) do
      Dir.chdir '../../..'
    end

    it 'should find and load the osa' do
      expect(@translator).not_to be_nil
    end

    it 'should load the analysis' do
      expect(@translator.osa.class).to eq(Hash)
      expect(@translator.osa).not_to eq({})
    end

    it 'should not have measure_paths and ../lib in file paths' do
      expect(@translator.file_paths).to eq(['../lib'])
      expect(@translator.measure_paths).to eq([])
    end

    it 'should have steps' do
      expect(@translator.steps.class).to eq(Array)
      expect(@translator.steps).not_to eq([])
      @translator.steps.each do |step|
        expect(step.class).to eq(Hash)
        expect(step).not_to eq({})
      end
    end
  end
  
  context 'write individual osws' do
    let(:osa_path) { 'analysis.osa' }

    before(:each) do
      FileUtils.mkdir_p 'spec/files/export/workflow' unless Dir.exist? 'spec/files/export/workflow'

      Dir.chdir 'spec/files/workflow'
      @translator = OpenStudio::Analysis::Translator::Workflow.new(osa_path)
    end

    after(:each) do
      Dir.chdir '../../..'
    end

    it 'should write a single osd' do
      osd_path = 'datapoint_0.osd'
      result = @translator.process_datapoint(osd_path)
      expect(result).to be_a(Hash)

      # Save the file to the export directory
      File.open('../../../spec/files/export/workflow/0.osw', 'w') { |f| f << JSON.pretty_generate(result) }

      expect(result.key?(:seed_model)).to eq false
      expect(result[:seed_file]).to eq 'large_office_air_cooled_chiller.osm'
      expect(result[:weather_file]).to eq 'USA_CO_Denver.Intl.AP.725650_TMY3.epw'
      expect(result[:file_format_version]).to eq '0.0.1'
    end

    it 'should not write a osd with a different osa id' do
      osd_path = 'datapoint_wrong_osa_id.osd'
      expect { @translator.process_datapoint(osd_path).first }.to raise_error(RuntimeError)
    end

    it 'should write several osds' do
      osd_paths = ['datapoint_0.osd', 'datapoint_1.osd', 'datapoint_2.osd']
      r = @translator.process_datapoints(osd_paths)
      expect(r.size).to eq 3
    end

    it 'should not fail when one osd is bad' do
      osd_paths = ['datapoint_0.osd', 'datapoint_1.osd', 'datapoint_wrong_osa_id.osd']
      r = @translator.process_datapoints(osd_paths)
      expect(r[0]).to be_a Hash
      expect(r[2]).to eq nil
    end
  end
end
