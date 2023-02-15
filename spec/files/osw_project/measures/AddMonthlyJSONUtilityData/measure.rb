# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
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
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'json'
require 'time'

# start the measure
class AddMonthlyJSONUtilityData < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    'Add Monthly JSON Utility Data'
  end

  # human readable description
  def description
    'Add Monthly JSON Utility Data'
  end

  # human readable description of modeling approach
  def modeler_description
    'Add Monthly JSON Formatted Utility Data to OSM as a UtilityBill Object'
  end

  def year_month_day(str)
    result = nil
    if match_data = /(\d+)(\D)(\d+)(\D)(\d+)/.match(str)
      if match_data[1].size == 4 # yyyy-mm-dd
        year = match_data[1].to_i
        month = match_data[3].to_i
        day = match_data[5].to_i
        result = [year, month, day]
      elsif match_data[5].size == 4 # mm-dd-yyyy
        year = match_data[5].to_i
        month = match_data[1].to_i
        day = match_data[3].to_i
        result = [year, month, day]
      end
    else
      puts "no match for '#{str}'"
    end
    result
  end

  # define the arguments that the user will input
  def arguments(_model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # set path to json
    json = OpenStudio::Measure::OSArgument.makeStringArgument('json', true)
    json.setDisplayName('Path to JSON Data in the Server.')
    json.setDescription('Path to JSON Data in the Server. calibration_data is directory name of uploaded files.')
    json.setDefaultValue('../../../lib/calibration_data/electric.json')
    args << json

    # set variable name
    variable_name = OpenStudio::Measure::OSArgument.makeStringArgument('variable_name', true)
    variable_name.setDisplayName('Variable name')
    variable_name.setDescription('Name of the Utility Bill Object.  For Calibration Report use Electric Bill or Gas Bill')
    variable_name.setDefaultValue('Electric Bill')
    args << variable_name

    # set fuel type
    fuel_type = OpenStudio::Measure::OSArgument.makeStringArgument('fuel_type', true)
    fuel_type.setDisplayName('Fuel Type')
    fuel_type.setDescription('Fuel Type')
    fuel_type.setDefaultValue('Electricity')
    args << fuel_type

    # set ConsumptionUnit
    consumption_unit = OpenStudio::Measure::OSArgument.makeStringArgument('consumption_unit', true)
    consumption_unit.setDisplayName('Consumption Unit')
    consumption_unit.setDescription('Consumption Unit (usually kWh or therms)')
    consumption_unit.setDefaultValue('kWh')
    args << consumption_unit

    # set data key name in json
    data_key_name = OpenStudio::Measure::OSArgument.makeStringArgument('data_key_name', true)
    data_key_name.setDisplayName('data key name in JSON')
    data_key_name.setDescription('data key name in JSON')
    data_key_name.setDefaultValue('tot_kwh')
    args << data_key_name

    # make a start date argument
    start_date = OpenStudio::Measure::OSArgument.makeStringArgument('start_date', true)
    start_date.setDisplayName('Start date')
    start_date.setDescription('Start date format %Y%m%dT%H%M%S with Hour Min Sec optional')
    start_date.setDefaultValue('2013-01-1')
    args << start_date

    # make an end date argument
    end_date = OpenStudio::Measure::OSArgument.makeStringArgument('end_date', true)
    end_date.setDisplayName('End date')
    end_date.setDescription('End date format %Y%m%dT%H%M%S with Hour Min Sec optional')
    end_date.setDefaultValue('2013-12-31')
    args << end_date

    # make an end date argument
    remove_utility_bill_data = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_existing_data', true)
    remove_utility_bill_data.setDisplayName('remove all existing Utility Bill data objects from model')
    remove_utility_bill_data.setDescription('remove all existing Utility Bill data objects from model')
    remove_utility_bill_data.setDefaultValue(false)
    args << remove_utility_bill_data

    # make an end date argument
    set_runperiod = OpenStudio::Measure::OSArgument.makeBoolArgument('set_runperiod', true)
    set_runperiod.setDisplayName('Set RunPeriod Object in model to use start and end dates')
    set_runperiod.setDescription('Set RunPeriod Object in model to use start and end dates.  Only needed once if multiple copies of measure being used.')
    set_runperiod.setDefaultValue(false)
    args << set_runperiod

    args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    json = runner.getStringArgumentValue('json', user_arguments)
    variable_name = runner.getStringArgumentValue('variable_name', user_arguments)
    fuel_type = runner.getStringArgumentValue('fuel_type', user_arguments)
    consumption_unit = runner.getStringArgumentValue('consumption_unit', user_arguments)
    data_key_name = runner.getStringArgumentValue('data_key_name', user_arguments)
    start_date = runner.getStringArgumentValue('start_date', user_arguments)
    end_date = runner.getStringArgumentValue('end_date', user_arguments)
    remove_utility_bill_data = runner.getBoolArgumentValue('remove_existing_data', user_arguments)
    set_runperiod = runner.getBoolArgumentValue('set_runperiod', user_arguments)

    # set start date
    if date = year_month_day(start_date)
      start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(date[1]), date[2], date[0])
      # actual year of start date
      yearDescription = model.getYearDescription
      yearDescription.setCalendarYear(date[0])
      if set_runperiod
        runPeriod = model.getRunPeriod
        runPeriod.setBeginMonth(date[1])
        runPeriod.setBeginDayOfMonth(date[2])
        runner.registerInfo("RunPeriod start date set to #{start_date}")
      end
    else
      runner.registerError("Unknown start date '#{start_date}'")
      raise "Unknown start date '#{start_date}'"
      return false
    end

    # set end date
    if date = year_month_day(end_date)
      end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(date[1]), date[2], date[0])
      if set_runperiod
        runPeriod = model.getRunPeriod
        runPeriod.setEndMonth(date[1])
        runPeriod.setEndDayOfMonth(date[2])
        runner.registerInfo("RunPeriod end date set to #{end_date}")
      end
    else
      runner.registerError("Unknown end date '#{end_date}'")
      raise "Unknown end date '#{end_date}'"
      return false
    end

    # remove all utility bills
    model.getUtilityBills.each(&:remove) if remove_utility_bill_data

    runner.registerInfo("json is #{json}")
    json_path = File.expand_path(json.to_s, __FILE__)
    runner.registerInfo("json_path is #{json_path}")
    temp = File.read(json_path)
    json_data = JSON.parse(temp)
    unless json_data.nil?
      runner.registerInfo("fuel_type is #{fuel_type}")
      utilityBill = OpenStudio::Model::UtilityBill.new(fuel_type.to_s.to_FuelType, model)
      utilityBill.setName(variable_name.to_s)
      utilityBill.setConsumptionUnit(consumption_unit.to_s)

      json_data['data'].each do |period|
        begin
          from_date = period['from'] ? Time.iso8601(period['from']).strftime('%Y%m%dT%H%M%S') : nil
          to_date = period['to'] ? Time.iso8601(period['to']).strftime('%Y%m%dT%H%M%S') : nil
        rescue ArgumentError => e
          runner.registerError("Unknown date format in period '#{period}'")
        end
        if from_date.nil? || to_date.nil?
          runner.registerError("Unknown date format in period '#{period}'")
          raise "Unknown date format in period '#{period}'"
          return false
        end
        # runner.registerInfo("GC.start")
        # GC.start
        period_start_date = OpenStudio::DateTime.fromISO8601(from_date).get.date
        # period_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(from_date[1]), from_date[2], from_date[0])
        # period_end_date = OpenStudio::DateTime.fromISO8601(to_date).get.date - OpenStudio::Time.new(1.0)
        period_end_date = OpenStudio::DateTime.fromISO8601(to_date).get.date
        # period_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(to_date[1]), to_date[2], to_date[0])

        if (period_start_date < start_date) || (period_end_date > end_date)
          runner.registerInfo("skipping period #{period_start_date} to #{period_end_date}")
          next
        end

        if period[data_key_name.to_s].nil?
          runner.registerError("Billing period missing key:#{data_key_name} in: '#{period}'")
          return false
        end
        data_key_value = period[data_key_name.to_s].to_f

        # peak_kw = nil
        # if not period['peak_kw'].nil?
        # peak_kw = period['peak_kw'].to_f
        # end

        runner.registerInfo("period #{period}")
        runner.registerInfo("period_start_date: #{period_start_date}, period_end_date: #{period_end_date}, #{data_key_name}: #{data_key_value}")

        bp = utilityBill.addBillingPeriod
        bp.setStartDate(period_start_date)
        bp.setEndDate(period_end_date)
        bp.setConsumption(data_key_value)
        # if peak_kw
        # bp.setPeakDemand(peak_kw)
        # end
      end
    end

    # reporting final condition of model
    runner.registerFinalCondition('Utility bill data has been added to the model.')

    true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
AddMonthlyJSONUtilityData.new.registerWithApplication
