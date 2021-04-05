# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
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

describe OpenStudio::Analysis::WorkflowStep do
  it 'should create a workflow' do
    s = OpenStudio::Analysis::WorkflowStep.new
    expect(s).not_to be nil
    expect(s).to be_a OpenStudio::Analysis::WorkflowStep
  end

  it 'should add a measure' do
    # convert XML to hash
    xml_file = 'spec/files/measures/IncreaseInsulationRValueForRoofs/measure.xml'
    h = parse_measure_xml(xml_file)
    s = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(s.name).to eq 'my_instance'
    expect(s.measure_definition_class_name).to eq 'IncreaseInsulationRValueForRoofs'
    expect(s.type).to eq 'ModelMeasure'
    expect(s.measure_definition_uuid).to eq '5fdd943e-ddd1-44b4-ae2d-94373fd71a78'
    expect(s.measure_definition_version_uuid).to eq 'c7800259-d525-4a08-b70d-dd261ca13353'
  end

  it 'should tag a discrete variable' do
    xml_file = 'spec/files/measures/SetThermostatSchedules/measure.xml'
    h = parse_measure_xml(xml_file)
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'discrete',
      minimum: 'low string',
      maximum: 'high string',
      mean: 'middle string',
      values: ['a', 'b', 'c', 'd'],
      weights: [0.25, 0.25, 0.25, 0.25]
    }
    r = measure.make_variable('cooling_sch', 'my variable', v)
    expect(r).to eq true
  end

  it 'should tag a continuous variable' do
    xml_file = 'spec/files/measures/SetThermostatSchedules/measure.xml'
    h = parse_measure_xml(xml_file)
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'triangle',
      minimum: 0.5,
      maximum: 20,
      mean: 10
    }
    o = {
      static_value: 24601
    }
    r = measure.make_variable('cooling_sch', 'my variable', v, o)

    h = measure.to_hash

    expect(h[:variables].first[:static_value]).to eq 24601
    expect(h[:variables].first.key?(:step_size)).to eq false

    expect(r).to eq true
  end

  it 'should tag a normal continuous variable' do
    xml_file = 'spec/files/measures/SetThermostatSchedules/measure.xml'
    h = parse_measure_xml(xml_file)

    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'normal',
      minimum: 0.5,
      maximum: 20,
      mean: 10,
      standard_deviation: 2
    }
    r = measure.make_variable('cooling_sch', 'my variable', v)

    h = measure.to_hash

    expect(h[:variables].first.key?(:step_size)).to eq false

    expect(r).to eq true
  end

  it 'should tag a uniform variable' do
    xml_file = 'spec/files/measures/SetThermostatSchedules/measure.xml'
    h = parse_measure_xml(xml_file)
    measure = OpenStudio::Analysis::WorkflowStep.from_measure_hash(
      'my_instance',
      'my instance display name',
      xml_file,
      h
    )

    expect(measure.name).to eq 'my_instance'
    v = {
      type: 'uniform',
      minimum: 0.5,
      maximum: 20,
      mean: 10
    }
    r = measure.make_variable('cooling_sch', 'my variable', v)

    h = measure.to_hash

    # puts JSON.pretty_generate(h)
    expect(h[:variables].first.key?(:step_size)).to eq false

    expect(r).to eq true
  end
end
