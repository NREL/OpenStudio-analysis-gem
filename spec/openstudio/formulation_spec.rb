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

describe OpenStudio::Analysis::Formulation do
  it 'should create an analysis' do
    a = OpenStudio::Analysis.create('Name of an analysis')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name of an analysis'
    expect(a).to be_a OpenStudio::Analysis::Formulation
  end

  it 'should add measure paths' do
    expect(OpenStudio::Analysis.measure_paths).to eq ['./measures']
    OpenStudio::Analysis.measure_paths = ['a', 'b']
    expect(OpenStudio::Analysis.measure_paths).to eq ['a', 'b']

    # append a measure apth
    OpenStudio::Analysis.measure_paths << 'c'
    expect(OpenStudio::Analysis.measure_paths).to eq ['a', 'b', 'c']
  end

  it 'should have a workflow object' do
    a = OpenStudio::Analysis.create('workflow')
    expect(a.workflow).not_to be nil
  end

  it 'should load the workflow from a file' do
    OpenStudio::Analysis.measure_paths << 'spec/files/measures'
    a = OpenStudio::Analysis.create('workflow')
    file = File.join('spec/files/analysis/examples/medium_office_workflow.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
  end

  it 'should save a hash (version 1)' do
    OpenStudio::Analysis.measure_paths << 'spec/files/measures'
    a = OpenStudio::Analysis.create('workflow 2')
    file = File.join('spec/files/analysis/examples/medium_office_workflow.json')
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
    h = a.to_hash
    # expect(h[:workflow].empty?).not_to eq true
  end

  it 'should read from windows fqp' do
    OpenStudio::Analysis.measure_paths << 'spec/files/measures'
    a = OpenStudio::Analysis.create('workflow 2')
    file = File.expand_path(File.join('spec/files/analysis/examples/medium_office_workflow.json'))
    file = file.tr('/', '\\') if Gem.win_platform?
    expect(a.workflow = OpenStudio::Analysis::Workflow.from_file(file)).not_to be nil
  end

  it 'should create a save an empty analysis' do
    a = OpenStudio::Analysis.create('workflow')
    run_dir = 'spec/files/export/workflow'

    FileUtils.mkdir_p run_dir

    h = a.to_hash
    expect(h[:analysis][:problem][:analysis_type]).to eq nil
    expect(a.save("#{run_dir}/analysis.json")).to eq true
  end

  it 'should increment objective functions' do
    a = OpenStudio::Analysis.create('my analysis')

    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2',
      objective_function: true
    )

    expect(a.to_hash[:analysis][:output_variables].first[:objective_function_index]).to eq 0

    a.add_output(
      display_name: 'Another Output',
      name: 'standard_report_legacy.output_2',
      units: 'MJ/m2',
      objective_function: true
    )
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 1

    a.add_output(
      display_name: 'Another Output Not Objective Function',
      name: 'standard_report_legacy.output_3',
      units: 'MJ/m2',
      objective_function: false
    )

    a.add_output(
      display_name: 'Another Output 4',
      name: 'standard_report_legacy.output_4',
      units: 'MJ/m2',
      objective_function: true
    )
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function_index]).to eq 2
  end

  it 'should not add the same output' do
    a = OpenStudio::Analysis.create('my analysis')

    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2',
      objective_function: true
    )

    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2',
      objective_function: false # this doesn't do anything
    )

    expect(a.to_hash[:analysis][:output_variables].size).to eq 1
    expect(a.to_hash[:analysis][:output_variables].last[:objective_function]).to eq true
  end

  it 'should create a new formulation' do
    a = OpenStudio::Analysis.create('my analysis')
    #p = 'spec/files/measures/SetThermostatSchedules'

    #a.workflow.add_measure_from_path('thermostat', 'thermostat', p)
    #m = a.workflow.add_measure_from_path('thermostat_2', 'thermostat 2', p)

    d = {
      type: 'uniform',
      minimum: 5,
      maximum: 7,
      mean: 6.2
    }
    #m.make_variable('cooling_sch', 'Change the cooling schedule', d)
    #m.argument_value('heating_sch', 'some-string')

    #expect(a.workflow.measures.size).to eq 2
    #expect(a.workflow.measures[1].arguments[3][:value]).to eq 'some-string'
    #expect(a.workflow.measures[1].variables[0][:uuid]).to match /[\w]{8}(-[\w]{4}){3}-[\w]{12}/

    a.analysis_type = 'single_run'
    a.algorithm.set_attribute('sample_method', 'all_variables')
    o = {
      display_name: 'Total Natural Gas',
      display_name_short: 'Total Natural Gas',
      metadata_id: nil,
      name: 'total_natural_gas',
      units: 'MJ/m2',
      objective_function: true,
      objective_function_index: 0,
      objective_function_target: 330.7,
      scaling_factor: nil,
      objective_function_group: nil
    }
    a.add_output(o)

    a.seed_model = 'spec/files/small_seed.osm'
    a.weather_file = 'spec/files/partial_weather.epw'

    expect(a.seed_model.first).to eq 'spec/files/small_seed.osm'

    expect(a.to_hash[:analysis][:problem][:algorithm][:objective_functions]).to match ['total_natural_gas']
    expect(a.analysis_type).to eq 'single_run'

    dp_hash = a.to_static_data_point_hash
    #expect(dp_hash[:data_point][:set_variable_values].values).to eq ['*No Change*']
  end
end
