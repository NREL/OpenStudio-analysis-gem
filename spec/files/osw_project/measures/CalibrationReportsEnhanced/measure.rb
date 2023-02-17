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

require 'erb'
require 'json'

# start the measure
class CalibrationReportsEnhanced < OpenStudio::Measure::ReportingMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    'Calibration Reports Enhanced'
  end

  # human readable description
  def description
    'This measure is intended for calibibration of modeled results against user entered utility bill.'
  end

  # human readable description of modeling approach
  def modeler_description
    'Measure looks at consumption for electricity and natural gas, and demand for electricity. It is inteneded to be used with no more than one gas an electric bills. Each bill can have multiple billing periods. Make sure ot use an AMY matching the utility data time frame.'
  end

  # define the arguments that the user will input
  def arguments(model = nil)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Electric NMBE limit
    electric_nmbe_limit = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_nmbe_limit', true)
    electric_nmbe_limit.setDisplayName('Electric NMBE limit (%)')
    electric_nmbe_limit.setDefaultValue(5.0)
    args << electric_nmbe_limit

    # Electric CVRMSE limit
    electric_cvrmse_limit = OpenStudio::Measure::OSArgument.makeDoubleArgument('electric_cvrmse_limit', true)
    electric_cvrmse_limit.setDisplayName('Electric CVRMSE limit (%)')
    electric_cvrmse_limit.setDefaultValue(15.0)
    args << electric_cvrmse_limit

    # Gas NMBE limit
    gas_nmbe_limit = OpenStudio::Measure::OSArgument.makeDoubleArgument('gas_nmbe_limit', true)
    gas_nmbe_limit.setDisplayName('Gas NMBE limit (%)')
    gas_nmbe_limit.setDefaultValue(5.0)
    args << gas_nmbe_limit

    # Gas CVRMSE limit
    gas_cvrmse_limit = OpenStudio::Measure::OSArgument.makeDoubleArgument('gas_cvrmse_limit', true)
    gas_cvrmse_limit.setDisplayName('Gas CVRMSE limit (%)')
    gas_cvrmse_limit.setDefaultValue(15.0)
    args << gas_cvrmse_limit

    # Fuel Oil NMBE limit
    fuel_oil_nmbe_limit = OpenStudio::Measure::OSArgument.makeDoubleArgument('fuel_oil_nmbe_limit', true)
    fuel_oil_nmbe_limit.setDisplayName('Fuel Oil#2 NMBE limit (%)')
    fuel_oil_nmbe_limit.setDefaultValue(5.0)
    args << fuel_oil_nmbe_limit

    # Fuel Oil CVRMSE limit
    fuel_oil_cvrmse_limit = OpenStudio::Measure::OSArgument.makeDoubleArgument('fuel_oil_cvrmse_limit', true)
    fuel_oil_cvrmse_limit.setDisplayName('Fuel Oil#2 CVRMSE limit (%)')
    fuel_oil_cvrmse_limit.setDefaultValue(15.0)
    args << fuel_oil_cvrmse_limit

    args
  end # end the arguments method

  def outputs
    result = OpenStudio::Measure::OSOutputVector.new

    # electric consumption values
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_consumption_actual') # kWh
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_consumption_modeled') # kWh
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_consumption_cvrmse') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_consumption_nmbe') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_sum_of_squares') # kWh
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_dof') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_rmse') # kWh^0.5

    # electric peak values
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_peak_demand_nmbe') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_peak_demand_actual') # kW
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_peak_demand_modeled') # kW

    # gas consumption values
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_consumption_actual') # therms
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_consumption_modeled') # therms
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_consumption_cvrmse') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_consumption_nmbe') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_sum_of_squares') # therms
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_dof') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_rmse') # therms^0.5

    # fuel oil #2 consumption values
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_consumption_actual') # gals
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_consumption_modeled') # gals
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_consumption_cvrmse') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_consumption_nmbe') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_sum_of_squares') # gals
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_dof') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_rmse') # gals^0.5

    # total fuel values (gas plus electric only? not district?)
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('total_sum_of_squares') # kBtu
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('total_dof') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('total_rmse') # kBtu^0.5

    # within limit check values
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_cvrmse_within_limit') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('electricity_nmbe_within_limit') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_cvrmse_within_limit') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('natural_gas_nmbe_within_limit') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_cvrmse_within_limit') # na
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('fuel_oil_2_nmbe_within_limit') # na

    result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    return false unless runner.validateUserArguments(arguments, user_arguments)

    electric_nmbe_limit = runner.getDoubleArgumentValue('electric_nmbe_limit', user_arguments)
    electric_cvrmse_limit = runner.getDoubleArgumentValue('electric_cvrmse_limit', user_arguments)
    gas_nmbe_limit = runner.getDoubleArgumentValue('gas_nmbe_limit', user_arguments)
    gas_cvrmse_limit = runner.getDoubleArgumentValue('gas_cvrmse_limit', user_arguments)
    fuel_oil_nmbe_limit = runner.getDoubleArgumentValue('fuel_oil_nmbe_limit', user_arguments)
    fuel_oil_cvrmse_limit = runner.getDoubleArgumentValue('fuel_oil_cvrmse_limit', user_arguments)

    os_version = OpenStudio::VersionString.new(OpenStudio.openStudioVersion)
    min_version_feature1 = OpenStudio::VersionString.new('1.2.2')

    # get the last model and sql file

    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    # put data into variables, these are available in the local scope binding
    # building_name = model.getBuilding.name.get

    web_asset_path = OpenStudio.getSharedResourcesPath / OpenStudio::Path.new('web_assets')

    energy = ''

    calibrationGuidelines = OpenStudio::Model::UtilityBill.calibrationGuidelines
    energy << 'var calibrationGuidelines  = ['
    calibrationGuidelines.each do |calibrationGuideline|
      energy << '"' << calibrationGuideline << '",'
    end
    energy = energy[0..-2]
    energy << "];\n"

    maxNMBE = OpenStudio::Model::UtilityBill.maxNMBE(calibrationGuidelines[0])
    energy << 'var ashraeMaxNMBE = '
    energy << if !maxNMBE.empty?
                maxNMBE.get.to_s
              else
                'N/A'
              end
    energy << ";\n"
    if os_version >= min_version_feature1
      runner.registerValue('ashrae_max_nmbe', maxNMBE.get, '%')
    end

    maxCVRMSE = OpenStudio::Model::UtilityBill.maxCVRMSE(calibrationGuidelines[0])
    energy << 'var ashraeMaxCVRMSE = '
    energy << if !maxCVRMSE.empty?
                maxCVRMSE.get.to_s
              else
                'N/A'
              end
    energy << ";\n"
    if os_version >= min_version_feature1
      runner.registerValue('ashrae_max_cvrmse', maxCVRMSE.get, '%')
    end

    maxNMBE = OpenStudio::Model::UtilityBill.maxNMBE(calibrationGuidelines[1])
    energy << 'var fempMaxNMBE = '
    energy << if !maxNMBE.empty?
                maxNMBE.get.to_s
              else
                'N/A'
              end
    energy << ";\n"
    if os_version >= min_version_feature1
      runner.registerValue('femp_max_nmbe', maxNMBE.get, '%')
    end

    maxCVRMSE = OpenStudio::Model::UtilityBill.maxCVRMSE(calibrationGuidelines[1])
    energy << 'var fempMaxCVRMSE = '
    energy << if !maxCVRMSE.empty?
                maxCVRMSE.get.to_s
              else
                'N/A'
              end
    energy << ";\n"
    if os_version >= min_version_feature1
      runner.registerValue('femp_max_cvrmse', maxCVRMSE.get, '%')
    end

    energyElec = "\t\"Electricity Consumption\":{\n\t\t\"units\":\"kWh\",\n"
    energyDemand =  "\t\"Electricity Demand\":{\n\t\t\"units\":\"kW\",\n"
    energyGas = "\t\"Natural Gas Consumption\":{\n\t\t\"units\":\"therms\",\n"
    energyFuelOil = "\t\"Fuel Oil 2 Consumption\":{\n\t\t\"units\":\"gals\",\n"
    tempStartDate = ''
    tempEndDate = ''
    elecStartDate = "\t\t\t\t\"Start\":["
    elecEndDate = "\t\t\t\t\"End\":["
    gasStartDate = "\t\t\t\t\"Start\":["
    gasEndDate = "\t\t\t\t\"End\":["
    fuelOilStartDate = "\t\t\t\t\"Start\":["
    fuelOilEndDate = "\t\t\t\t\"End\":["
    elecActualConsumption = "\t\t\t\t\"Actual\":["
    elecModelConsumption = "\t\t\t\t\"Model\":["
    actualPeakDemand = "\t\t\t\t\"Actual\":["
    modelPeakDemand = "\t\t\t\t\"Model\":["
    gasActualConsumption = "\t\t\t\t\"Actual\":["
    gasModelConsumption = "\t\t\t\t\"Model\":["
    fuelOilActualConsumption = "\t\t\t\t\"Actual\":["
    fuelOilModelConsumption = "\t\t\t\t\"Model\":["
    elecNMBE = "\t\t\t\t\"NMBE\":["
    demandNMBE = "\t\t\t\t\"NMBE\":["
    gasNMBE = "\t\t\t\t\"NMBE\":["
    fuelOilNMBE = "\t\t\t\t\"NMBE\":["
    peakDemandUnitConversionFactor = 1.0
    consumptionUnitConversionFactor = 1.0
    hasElec = false
    hasDemand = false
    hasGas = false
    hasFuelOil = false

    missingData = false
    # must have a runPeriod
    runPeriod = model.runPeriod
    if runPeriod.empty?
      missingData = true
      runner.registerWarning('Model has no run period and cannot generate all data.')
    end

    # must have a calendarYear to generate model data
    yearDescription = model.yearDescription
    if yearDescription.empty?
      missingData = true
      runner.registerWarning('Model has no year description and cannot generate all data.')
    end
    calendarYear = yearDescription.get.calendarYear
    if calendarYear.empty?
      missingData = true
      runner.registerWarning('Model has no calendar year and cannot generate all data.')
    end

    all_actual_consumption_values = []
    all_modeled_consumption_values = []

    # sort bills by fuel type and name
    utilityBills = model.getUtilityBills.sort { |x, y| (x.fuelType.valueDescription + x.name.get) <=> (y.fuelType.valueDescription + y.name.get) }
    registered_fuel_types = []

    utilityBills.each do |utilityBill|
      fuel_type = utilityBill.fuelType.to_s
      utility_bill_name = OpenStudio.toUnderscoreCase(utilityBill.name.get)
      utility_bill_fuel_type = OpenStudio.toUnderscoreCase(utilityBill.fuelType.valueDescription)
      if registered_fuel_types.include?(utility_bill_fuel_type)
        runner.registerWarning("More than one utility bill of fuel type #{utility_bill_fuel_type} is in the model. Skipping #{utility_bill_name}.")
        next
      else
        registered_fuel_types << utility_bill_fuel_type
      end

      cvrsme = 0.0
      unless utilityBill.CVRMSE.empty?
        cvrsme = utilityBill.CVRMSE.get
        if os_version >= min_version_feature1
          runner.registerValue("#{utility_bill_fuel_type}_consumption_cvrmse", cvrsme, '%')
        end
        cvrsme = format '%.2f', cvrsme
      end

      nmbe = 0.0
      unless utilityBill.NMBE.empty?
        nmbe = utilityBill.NMBE.get
        if os_version >= min_version_feature1
          runner.registerValue("#{utility_bill_fuel_type}_consumption_nmbe", nmbe, '%')
        end
        nmbe = format '%.2f', nmbe
      end

      string = ''
      string << "\t\t\"cvrsme\":\"" << cvrsme.to_s << "\",\n\t\t\"nmbe\":\"" << nmbe.to_s << "\",\n\t\t\t\"data\":{\n"

      hasDemandValues = false
      if !utilityBill.peakDemandUnitConversionFactor.empty?
        hasDemandValues = true
        energyElec << string
        energyDemand << string
        peakDemandUnitConversionFactor = utilityBill.peakDemandUnitConversionFactor.get
      elsif utility_bill_fuel_type == 'natural_gas' # NaturalGas
        hasDemandValues = false
        energyGas << string
      elsif utility_bill_fuel_type == 'fuel_oil_2' # FuelOil_2
        hasDemandValues = false
        energyFuelOil << string
      else
        runner.registerWarning("#{utility_bill_fuel_type} is an unsupported fuel type.")
      end

      consumptionUnitConversionFactor = utilityBill.consumptionUnitConversionFactor

      period_index = 1
      actual_consumption = 0.0
      modeled_consumption = 0.0
      actual_consumption_values = []
      modeled_consumption_values = []
      actual_demand = 0.0
      modeled_demand = 0.0

      utilityBill.billingPeriods.each do |billingPeriod|
        tempStartDate = '"' << billingPeriod.startDate.monthOfYear.value.to_s
        tempStartDate << '/'
        tempStartDate << billingPeriod.startDate.dayOfMonth.to_s << '"'
        tempEndDate =  '"' << billingPeriod.endDate.monthOfYear.value.to_s
        tempEndDate << '/'
        tempEndDate << billingPeriod.endDate.dayOfMonth.to_s << '"'
        if os_version >= min_version_feature1
          runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_start_date", billingPeriod.startDate.to_s)
          runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_end_date", billingPeriod.endDate.to_s)
        end

        if hasDemandValues
          elecStartDate << tempStartDate << ','
          elecEndDate << tempEndDate << ','

          consumption = billingPeriod.consumption
          if !consumption.empty?
            hasElec = true
            elecActualConsumption << consumption.get.to_s
            actual_consumption += consumption.get
            actual_consumption_values << consumption.get
            all_actual_consumption_values << consumption.get * utilityBill.consumptionUnitConversionFactor
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_actual",
                                   consumption.get,
                                   utilityBill.consumptionUnit)
            end
          else
            elecActualConsumption << '0'
          end
          elecActualConsumption << ','

          consumption = billingPeriod.modelConsumption
          if !consumption.empty?
            hasElec = true
            temp = consumption.get / consumptionUnitConversionFactor
            elecModelConsumption << temp.round(2).to_s
            modeled_consumption += temp
            modeled_consumption_values << temp
            all_modeled_consumption_values << consumption.get
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_modeled",
                                   temp,
                                   utilityBill.consumptionUnit)
            end
          else
            elecModelConsumption << '0'
          end
          elecModelConsumption << ','

          peakDemand = billingPeriod.peakDemand
          if !peakDemand.empty?
            hasDemand = true
            actualPeakDemand << peakDemand.get.to_s
            actual_demand = peakDemand.get if peakDemand.get > actual_demand
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_peak_demand_actual",
                                   peakDemand.get,
                                   utilityBill.peakDemandUnit.get)
            end
          else
            actualPeakDemand << '0'
          end
          actualPeakDemand << ','

          peakDemand = billingPeriod.modelPeakDemand
          if !peakDemand.empty?
            hasDemand = true
            temp = peakDemand.get / 1000
            temp_str = format '%.1f', temp
            modelPeakDemand << temp_str.to_s
            modeled_demand = temp if temp > modeled_demand
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_peak_demand_modeled",
                                   temp,
                                   utilityBill.peakDemandUnit.get)
            end
          else
            modelPeakDemand << '0'
          end
          modelPeakDemand << ','

          if !billingPeriod.peakDemand.empty? && !billingPeriod.modelPeakDemand.empty? && (billingPeriod.consumption.get != 0)
            percent = 100 * ((billingPeriod.modelPeakDemand.get / 1000) - billingPeriod.peakDemand.get) / billingPeriod.peakDemand.get
            percent_str = format '%.2f', percent
            demandNMBE << percent_str.to_s
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_peak_demand_nmbe",
                                   percent,
                                   '%')
            end
          else
            demandNMBE << '0'
          end
          demandNMBE << ','

          if !billingPeriod.consumption.empty? && !billingPeriod.modelConsumption.empty? && (billingPeriod.consumption.get != 0)
            percent = 100 * ((billingPeriod.modelConsumption.get / consumptionUnitConversionFactor) - billingPeriod.consumption.get) / billingPeriod.consumption.get
            percent_str = format '%.2f', percent
            elecNMBE << percent_str.to_s
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_nmbe",
                                   percent,
                                   '%')
            end
          else
            elecNMBE << '0'
          end
          elecNMBE << ','

        elsif utility_bill_fuel_type == 'natural_gas' # NaturalGas
          gasStartDate << tempStartDate << ','
          gasEndDate << tempEndDate << ','

          consumption = billingPeriod.consumption
          if !consumption.empty?
            hasGas = true
            gasActualConsumption << consumption.get.to_s
            actual_consumption += consumption.get
            actual_consumption_values << consumption.get
            all_actual_consumption_values << consumption.get * utilityBill.consumptionUnitConversionFactor
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_actual",
                                   consumption.get,
                                   utilityBill.consumptionUnit)
            end
          else
            gasActualConsumption << '0'
          end
          gasActualConsumption << ','

          consumption = billingPeriod.modelConsumption
          if !consumption.empty?
            hasGas = true
            temp = consumption.get / consumptionUnitConversionFactor
            gasModelConsumption << temp.round(2).to_s
            modeled_consumption += temp
            modeled_consumption_values << temp
            all_modeled_consumption_values << consumption.get
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_modeled",
                                   temp,
                                   utilityBill.consumptionUnit)
            end
          else
            gasModelConsumption << '0'
          end
          gasModelConsumption << ','

          if !billingPeriod.consumption.empty? && !billingPeriod.modelConsumption.empty? && (billingPeriod.consumption.get != 0)
            percent = 100 * ((billingPeriod.modelConsumption.get / consumptionUnitConversionFactor) - billingPeriod.consumption.get) / billingPeriod.consumption.get
            percent_str = format '%.2f', percent
            gasNMBE << percent_str.to_s
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_nmbe",
                                   percent,
                                   '%')
            end
          else
            gasNMBE << '0'
          end
          gasNMBE << ','

        elsif utility_bill_fuel_type == 'fuel_oil_2' # FuelOil_2
          fuelOilStartDate << tempStartDate << ','
          fuelOilEndDate << tempEndDate << ','

          consumption = billingPeriod.consumption
          if !consumption.empty?
            hasFuelOil = true
            fuelOilActualConsumption << consumption.get.to_s
            actual_consumption += consumption.get
            actual_consumption_values << consumption.get
            all_actual_consumption_values << consumption.get * utilityBill.consumptionUnitConversionFactor
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_actual",
                                   consumption.get,
                                   utilityBill.consumptionUnit)
            end
          else
            fuelOilActualConsumption << '0'
          end
          fuelOilActualConsumption << ','

          consumption = billingPeriod.modelConsumption

          if !consumption.empty?
            hasFuelOil = true
            temp = consumption.get / consumptionUnitConversionFactor
            fuelOilModelConsumption << temp.round(2).to_s
            modeled_consumption += temp
            modeled_consumption_values << temp
            all_modeled_consumption_values << consumption.get
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_modeled",
                                   temp,
                                   utilityBill.consumptionUnit)
            end
          else
            fuelOilModelConsumption << '0'
            # TODO: - test after https://github.com/NREL/OpenStudio/issues 3316 is fixed
            runner.registerWarning("In OpenStudio 2.7.0 Fuel Oil modeled consumption by billing period isn't properly represented.")
          end
          fuelOilModelConsumption << ','

          if !billingPeriod.consumption.empty? && !billingPeriod.modelConsumption.empty? && (billingPeriod.consumption.get != 0)
            percent = 100 * ((billingPeriod.modelConsumption.get / consumptionUnitConversionFactor) - billingPeriod.consumption.get) / billingPeriod.consumption.get
            percent_str = format '%.2f', percent
            fuelOilNMBE << percent_str.to_s
            if os_version >= min_version_feature1
              runner.registerValue("#{utility_bill_fuel_type}_period_#{period_index}_consumption_nmbe",
                                   percent,
                                   '%')
            end
          else
            fuelOilNMBE << '0'
          end
          fuelOilNMBE << ','

        else
          runner.registerWarning("#{utility_bill_fuel_type} isn't a currently supported fuel type for this measure.")

        end
        period_index += 1
      end

      next unless os_version >= min_version_feature1
      if actual_consumption > 0.0
        runner.registerValue("#{utility_bill_fuel_type}_consumption_actual",
                             actual_consumption,
                             utilityBill.consumptionUnit)
        runner.registerValue("#{utility_bill_fuel_type}_consumption_modeled",
                             modeled_consumption,
                             utilityBill.consumptionUnit)
      end
      if actual_demand > 0.0
        runner.registerValue("#{utility_bill_fuel_type}_peak_demand_actual",
                             actual_demand,
                             utilityBill.peakDemandUnit.get)
        runner.registerValue("#{utility_bill_fuel_type}_peak_demand_modeled",
                             modeled_demand,
                             utilityBill.peakDemandUnit.get)
        runner.registerValue("#{utility_bill_fuel_type}_peak_demand_nmbe",
                             100.0 * (modeled_demand - actual_demand) / actual_demand,
                             '%')
      end
      next unless !actual_consumption_values.empty? && (actual_consumption_values.size == modeled_consumption_values.size)
      sum_squares = 0.0
      actual_consumption_values.each_index do |i|
        sum_squares += (actual_consumption_values[i] - modeled_consumption_values[i])**2
      end
      rmse = Math.sqrt(sum_squares / actual_consumption_values.size)
      runner.registerValue("#{utility_bill_fuel_type}_sum_of_squares",
                           sum_squares,
                           utilityBill.consumptionUnit)
      runner.registerValue("#{utility_bill_fuel_type}_dof",
                           actual_consumption_values.size)
      runner.registerValue("#{utility_bill_fuel_type}_rmse",
                           rmse,
                           utilityBill.consumptionUnit + '^0.5')
    end

    if os_version >= min_version_feature1
      if !all_actual_consumption_values.empty? && (all_actual_consumption_values.size == all_modeled_consumption_values.size)
        sum_squares = 0.0
        all_actual_consumption_values.each_index do |i|
          sum_squares += (all_actual_consumption_values[i] - all_modeled_consumption_values[i])**2
        end
        rmse = Math.sqrt(sum_squares / all_actual_consumption_values.size)
        runner.registerValue('total_sum_of_squares',
                             sum_squares,
                             'kBtu')
        runner.registerValue('total_dof',
                             all_actual_consumption_values.size)
        runner.registerValue('total_rmse',
                             rmse,
                             'kBtu^0.5')
      end

    end

    elecStartDate = elecStartDate[0..-2]
    elecStartDate << "],\n"
    elecEndDate = elecEndDate[0..-2]
    elecEndDate << "],\n"
    elecActualConsumption = elecActualConsumption[0..-2]
    elecActualConsumption << "],\n"
    elecModelConsumption = elecModelConsumption[0..-2]
    elecModelConsumption << "],\n"
    actualPeakDemand = actualPeakDemand[0..-2]
    actualPeakDemand << "],\n"
    modelPeakDemand = modelPeakDemand[0..-2]
    modelPeakDemand << "],\n"
    elecNMBE = elecNMBE[0..-2]
    elecNMBE << "]\n"
    demandNMBE = demandNMBE[0..-2]
    demandNMBE << "]\n"
    energyElec << elecStartDate << elecEndDate << elecActualConsumption << elecModelConsumption << elecNMBE
    energyElec << "\t\t}\n" << "\t},\n"

    energyDemand << elecStartDate << elecEndDate << actualPeakDemand << modelPeakDemand << demandNMBE
    energyDemand << "\t\t}\n" << "\t},\n"

    gasStartDate = gasStartDate[0..-2]
    gasStartDate << "],\n"
    gasEndDate = gasEndDate[0..-2]
    gasEndDate << "],\n"
    gasActualConsumption = gasActualConsumption[0..-2]
    gasActualConsumption << "],\n"
    gasModelConsumption = gasModelConsumption[0..-2]
    gasModelConsumption << "],\n"
    gasNMBE = gasNMBE[0..-2]
    gasNMBE << "]\n"
    energyGas << gasStartDate << gasEndDate << gasActualConsumption << gasModelConsumption << gasNMBE
    energyGas << "\t\t}\n" << "\t},\n"

    fuelOilStartDate = fuelOilStartDate[0..-2]
    fuelOilStartDate << "],\n"
    fuelOilEndDate = fuelOilEndDate[0..-2]
    fuelOilEndDate << "],\n"
    fuelOilActualConsumption = fuelOilActualConsumption[0..-2]
    fuelOilActualConsumption << "],\n"
    fuelOilModelConsumption = fuelOilModelConsumption[0..-2]
    fuelOilModelConsumption << "],\n"
    fuelOilNMBE = fuelOilNMBE[0..-2]
    fuelOilNMBE << "]\n"
    energyFuelOil << fuelOilStartDate << fuelOilEndDate << fuelOilActualConsumption << fuelOilModelConsumption << fuelOilNMBE
    energyFuelOil << "\t\t}\n" << "\t},\n"

    energy << "var consumption = {\n"

    energy << energyElec if hasElec

    energy << energyDemand if hasDemand

    energy << energyGas if hasGas

    energy << energyFuelOil if hasFuelOil
    energy << '};'

    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.in"
    html_in_path = if File.exist?(html_in_path)
                     html_in_path
                   else
                     "#{File.dirname(__FILE__)}/report.html.in"
                   end
    html_in = ''
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file
    html_out_path = './report.html'
    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue StandardError
        file.flush
      end
    end

    # closing the sql file
    sqlFile.close

    # reporting final condition
    if missingData == true
      runner.registerFinalCondition('Calibration Report was not generated successfully.')
    else
      runner.registerFinalCondition('Calibration Report generated successfully.')
    end

    # write json specific file format, everything can be derived from reported attributes
    result_hash = {}
    runner.result.attributes.each do |attribute|
      # skip individual period metrics
      next if /period_\d+_consumption/.match(attribute.name)

      if match_data = /(.*)_consumption_cvrmse/.match(attribute.name)
        cvrmse = attribute.valueAsDouble

        # this is a hack
        is_electric = /electric/i.match(match_data[1])

        within_limit = false
        within_limit = if is_electric
                         (cvrmse <= electric_cvrmse_limit)
                       else
                         (cvrmse <= gas_cvrmse_limit)
                       end
        result_hash[match_data[1] + '_cvrmse_within_limit'] = within_limit
        within_limit_i = if within_limit
                           1
                         else
                           0
                         end
        runner.registerValue("#{match_data[1]}_cvrmse_within_limit", within_limit_i)
      elsif match_data = /(.*)_consumption_nmbe/i.match(attribute.name)
        nmbe = attribute.valueAsDouble

        # this is a hack
        is_electric = /electric/i.match(match_data[1])

        within_limit = false
        within_limit = if is_electric
                         (nmbe.abs <= electric_nmbe_limit)
                       else
                         (nmbe.abs <= gas_nmbe_limit)
                       end
        result_hash[match_data[1] + '_nmbe_within_limit'] = within_limit
        within_limit_i = if within_limit
                           1
                         else
                           0
                         end
        runner.registerValue("#{match_data[1]}_nmbe_within_limit", within_limit_i)
      end
    end
    File.open('./report_guideline.json', 'w') do |f|
      f.write(result_hash.to_json)
    end

    true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
CalibrationReportsEnhanced.new.registerWithApplication
