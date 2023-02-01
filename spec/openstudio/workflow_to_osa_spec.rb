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
require 'json-schema'

describe 'Convert_an_OSW_to_OSA' do

  it 'should load an OSW from file and make OSA' do
    
    #check if file exists  
    osw_file = 'spec/files/osw_project/calibration_workflow.osw'
    expect(File.exist?(osw_file)).to be true

    #create OSA
    a = OpenStudio::Analysis.create('Name of an analysis')
    expect(a).not_to be nil
    expect(a.display_name).to eq 'Name of an analysis'
    expect(a).to be_a OpenStudio::Analysis::Formulation
    expect(a.workflow).not_to be nil
    
    #put OSW into OSA.workflow
    output = a.convert_osw(osw_file)
    expect(output).not_to be nil
    
    #expect measures to be in OSA workflow
    m = a.workflow.find_measure('add_monthly_json_utility_data')
    expect(m.argument_names).to eq ["__SKIP__", "json", "variable_name", "fuel_type", "consumption_unit", "data_key_name", "start_date", "end_date", "remove_existing_data", "set_runperiod"]
    
    #check argument is a Boolean and is True (default is false)
    arg = m.arguments.find_all { |a| a[:name] == 'remove_existing_data' }
    expect(arg[0][:value].class).to be TrueClass
    expect(arg[0][:value]).to eq(true)
    
    m = a.workflow.find_measure('add_monthly_json_utility_data_2')
    expect(m.argument_names).to eq ["__SKIP__", "json", "variable_name", "fuel_type", "consumption_unit", "data_key_name", "start_date", "end_date", "remove_existing_data", "set_runperiod"]
    
    m = a.workflow.find_measure('general_calibration_measure_percent_change')
    expect(m.argument_names).to eq ["__SKIP__", "space_type", "space", "lights_perc_change", "luminaire_perc_change", "ElectricEquipment_perc_change", "GasEquipment_perc_change", "OtherEquipment_perc_change", "people_perc_change", "mass_perc_change", "infil_perc_change", "vent_perc_change"]
    
    expect(a.workflow.measures.size).to eq 4
    expect(a.workflow.items.size).to eq 4

    expect(a.workflow.all_variables.size).to eq 0
    
    #check arguments are of the correct type adn value
    arg = m.arguments.find_all { |a| a[:name] == 'vent_perc_change' }
    expect(arg[0][:value].is_a? Float).to be true
    expect(arg[0][:value]).to eq(10.0)
    
    #check luminaire_perc_change did not change since its not in OSW
    arg = m.arguments.find_all { |a| a[:name] == 'luminaire_perc_change' }
    expect(arg[0][:value].is_a? Float).to be true
    expect(arg[0][:value]).to eq(0.0)
    
    #validate OSA against schema
    osa_schema = JSON.parse(File.read('spec/schema/osa_server_schema.json'), symbolize_names: true)
    errors = JSON::Validator.fully_validate(osa_schema, a.to_hash)
    expect(errors.empty?).to eq(true), "OSA is not valid, #{errors}"
  end

end
