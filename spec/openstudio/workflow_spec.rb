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

describe OpenStudio::Analysis::Workflow do
  before :all do
    @w = OpenStudio::Analysis::Workflow.new
  end

  it 'should create a workflow' do
    expect(@w).not_to be nil
    expect(@w).to be_a OpenStudio::Analysis::Workflow
  end

  it 'should add a measure' do
    p = 'spec/files/measures/IncreaseInsulationRValueForRoofs'
    expect(@w.add_measure_from_path('insulation', 'Increase Insulation', p)).to be_an OpenStudio::Analysis::WorkflowStep

    p = 'spec/files/measures/ActualMeasureNoJson'
    FileUtils.remove "#{p}/measure.json" if File.exist? "#{p}/measure.json"
    m = @w.add_measure_from_path('a_measure', 'Actual Measure', p)
    expect(m).to be_a OpenStudio::Analysis::WorkflowStep
    expect(m.measure_definition_class_name).to eq 'RotateBuilding'
  end

  it 'should fix the path of the measure' do
    p = 'spec/files/measures/IncreaseInsulationRValueForRoofs/measure.rb'
    m = @w.add_measure_from_path('insulation', 'Increase Insulation', p)
    expect(m).to be_an OpenStudio::Analysis::WorkflowStep
    expect(m.measure_definition_directory).to eq './measures/IncreaseInsulationRValueForRoofs'
    expect(m.measure_definition_directory_local).to eq 'spec/files/measures/IncreaseInsulationRValueForRoofs'
  end

  it 'should clear out a workflow' do
    p = 'spec/files/measures/SetThermostatSchedules'
    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat 2', 'thermostat 2', p)

    expect(@w.items.size).to be > 1
    @w.clear
    expect(@w.items.size).to eq 0

    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat 2', 'thermostat 2', p)
    expect(@w.items.size).to eq 2
  end

  it 'should find a workflow step' do
    @w.clear

    p = 'spec/files/measures/SetThermostatSchedules'
    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat_2', 'thermostat 2', p)

    m = @w.find_measure('thermostat_2')
    expect(m).not_to be nil
    expect(m).to be_a OpenStudio::Analysis::WorkflowStep
    expect(m.name).to eq 'thermostat_2'
  end

  it 'should find a workflow step and make a variable' do
    @w.clear

    p = 'spec/files/measures/SetThermostatSchedules'
    @w.add_measure_from_path('thermostat', 'thermostat', p)
    @w.add_measure_from_path('thermostat_2', 'thermostat 2', p)

    m = @w.find_measure('thermostat_2')
    expect(m.argument_names).to eq ['__SKIP__', 'zones', 'cooling_sch', 'heating_sch', 'material_cost']

    d = {
      type: 'uniform',
      minimum: 5,
      maximum: 7,
      mean: 6.2
    }
    m.make_variable('cooling_sch', 'Change the cooling schedule', d)

    d = {
      type: 'uniform',
      minimum: 5,
      maximum: 7,
      mean: 6.2
    }
    m.make_variable('heating_sch', 'Change the heating schedule', d)

    expect(@w.measures.size).to eq 2
    expect(@w.items.size).to eq 2
    expect(@w.items.size).to eq 2

    expect(@w.all_variables.size).to eq 2
  end
end
