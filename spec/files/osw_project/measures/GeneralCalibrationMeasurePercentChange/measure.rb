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

# start the measure
class GeneralCalibrationMeasurePercentChange < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    'General Calibration Measure Percent Change'
  end

  # human readable description
  def description
    'This is a general purpose measure to calibrate space and space type elements with a percent change.'
  end

  # human readable description of modeling approach
  def modeler_description
    'It will be used for calibration of space and spaceType loads as well as infiltration, and outdoor air. User can choose between a SINGLE SpaceType or ALL the SpaceTypes as well as a SINGLE Space or ALL the Spaces.'
  end

  def change_name(object, perc_change)
    if perc_change != 0
      object.setName("#{object.name.get} (#{perc_change.round(2)} percent change)")
    end
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a choice argument for model objects
    space_type_handles = OpenStudio::StringVector.new
    space_type_display_names = OpenStudio::StringVector.new

    # putting model object and names into hash
    space_type_args = model.getSpaceTypes
    space_type_args_hash = {}
    space_type_args.each do |space_type_arg|
      space_type_args_hash[space_type_arg.name.to_s] = space_type_arg
    end

    # looping through sorted hash of model objects
    space_type_args_hash.sort.map do |key, value|
      # only include if space type is used in the model
      unless value.spaces.empty?
        space_type_handles << value.handle.to_s
        space_type_display_names << key
      end
    end

    # add building to string vector with space type
    building = model.getBuilding
    space_type_handles << building.handle.to_s
    space_type_display_names << '*All SpaceTypes*'
    space_type_handles << '0'
    space_type_display_names << '*None*'

    # make a choice argument for space type
    space_type = OpenStudio::Measure::OSArgument.makeChoiceArgument('space_type', space_type_handles, space_type_display_names)
    space_type.setDisplayName('Apply the Measure to a SINGLE SpaceType, ALL the SpaceTypes or NONE.')
    space_type.setDefaultValue('*All SpaceTypes*') # if no space type is chosen this will run on the entire building
    args << space_type

    # make a choice argument for model objects
    space_handles = OpenStudio::StringVector.new
    space_display_names = OpenStudio::StringVector.new

    # putting model object and names into hash
    space_args = model.getSpaces
    space_args_hash = {}
    space_args.each do |space_arg|
      space_args_hash[space_arg.name.to_s] = space_arg
    end

    # looping through sorted hash of model objects
    space_args_hash.sort.map do |key, value|
      space_handles << value.handle.to_s
      space_display_names << key
    end

    # add building to string vector with spaces
    building = model.getBuilding
    space_handles << building.handle.to_s
    space_display_names << '*All Spaces*'
    space_handles << '0'
    space_display_names << '*None*'

    # make a choice argument for space type
    space = OpenStudio::Measure::OSArgument.makeChoiceArgument('space', space_handles, space_display_names)
    space.setDisplayName('Apply the Measure to a SINGLE Space, ALL the Spaces or NONE.')
    space.setDefaultValue('*All Spaces*') # if no space type is chosen this will run on the entire building
    args << space

    # Lights multiplier
    lights_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('lights_perc_change', true)
    lights_perc_change.setDisplayName('Percent Change in the default Lights Definition.')
    lights_perc_change.setDescription('Percent Change in the default Lights Definition.')
    lights_perc_change.setDefaultValue(0.0)
    args << lights_perc_change

    # Luminaire multiplier
    luminaire_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('luminaire_perc_change', true)
    luminaire_perc_change.setDisplayName('Percent Change in the default Luminaire Definition.')
    luminaire_perc_change.setDescription('Percent Change in the default Luminaire Definition.')
    luminaire_perc_change.setDefaultValue(0.0)
    args << luminaire_perc_change

    # Electric Equipment multiplier
    electric_equip_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('ElectricEquipment_perc_change', true)
    electric_equip_perc_change.setDisplayName('Percent Change in the default Electric Equipment Definition.')
    electric_equip_perc_change.setDescription('Percent Change in the default Electric Equipment Definition.')
    electric_equip_perc_change.setDefaultValue(0.0)
    args << electric_equip_perc_change

    # Gas Equipment multiplier
    gas_equip_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('GasEquipment_perc_change', true)
    gas_equip_perc_change.setDisplayName('Percent Change in the default Gas Equipment Definition.')
    gas_equip_perc_change.setDescription('Percent Change in the default Gas Equipment Definition.')
    gas_equip_perc_change.setDefaultValue(0.0)
    args << gas_equip_perc_change

    # OtherEquipment multiplier
    other_equip_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('OtherEquipment_perc_change', true)
    other_equip_perc_change.setDisplayName('Percent Change in the default OtherEquipment Definition.')
    other_equip_perc_change.setDescription('Percent Change in the default OtherEquipment Definition.')
    other_equip_perc_change.setDefaultValue(0.0)
    args << other_equip_perc_change

    # occupancy % change
    people_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('people_perc_change', true)
    people_perc_change.setDisplayName('Percent Change in the default People Definition.')
    people_perc_change.setDescription('Percent Change in the default People Definition.')
    people_perc_change.setDefaultValue(0.0)
    args << people_perc_change

    # internalMass % change
    mass_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('mass_perc_change', true)
    mass_perc_change.setDisplayName('Percent Change in the default Internal Mass Definition.')
    mass_perc_change.setDescription('Percent Change in the default Internal Mass Definition.')
    mass_perc_change.setDefaultValue(0.0)
    args << mass_perc_change

    # infiltration % change
    infil_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('infil_perc_change', true)
    infil_perc_change.setDisplayName('Percent Change in the default Design Infiltration Outdoor Air.')
    infil_perc_change.setDescription('Percent Change in the default Design Infiltration Outdoor Air.')
    infil_perc_change.setDefaultValue(0.0)
    args << infil_perc_change

    # ventilation % change
    vent_perc_change = OpenStudio::Measure::OSArgument.makeDoubleArgument('vent_perc_change', true)
    vent_perc_change.setDisplayName('Percent Change in the default Design Specification Outdoor Air.')
    vent_perc_change.setDescription('Percent Change in the default Design Specification Outdoor Air.')
    vent_perc_change.setDefaultValue(0.0)
    args << vent_perc_change

    args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    space_type_object = runner.getOptionalWorkspaceObjectChoiceValue('space_type', user_arguments, model)
    space_type_handle = runner.getStringArgumentValue('space_type', user_arguments)
    space_object = runner.getOptionalWorkspaceObjectChoiceValue('space', user_arguments, model)
    space_handle = runner.getStringArgumentValue('space', user_arguments)
    people_perc_change = runner.getDoubleArgumentValue('people_perc_change', user_arguments)
    infil_perc_change = runner.getDoubleArgumentValue('infil_perc_change', user_arguments)
    vent_perc_change = runner.getDoubleArgumentValue('vent_perc_change', user_arguments)
    mass_perc_change = runner.getDoubleArgumentValue('mass_perc_change', user_arguments)
    electric_equip_perc_change = runner.getDoubleArgumentValue('ElectricEquipment_perc_change', user_arguments)
    gas_equip_perc_change = runner.getDoubleArgumentValue('GasEquipment_perc_change', user_arguments)
    other_equip_perc_change = runner.getDoubleArgumentValue('OtherEquipment_perc_change', user_arguments)
    lights_perc_change = runner.getDoubleArgumentValue('lights_perc_change', user_arguments)
    luminaire_perc_change = runner.getDoubleArgumentValue('luminaire_perc_change', user_arguments)

    # find objects to change
    space_types = []
    spaces = []
    building = model.getBuilding
    building_handle = building.handle.to_s
    runner.registerInfo("space_type_handle: #{space_type_handle}")
    runner.registerInfo("space_handle: #{space_handle}")
    # setup space_types
    if space_type_handle == building_handle
      # Use ALL SpaceTypes
      runner.registerInfo('Applying change to ALL SpaceTypes')
      space_types = model.getSpaceTypes
    elsif space_type_handle == 0.to_s
      # SpaceTypes set to NONE so do nothing
      runner.registerInfo('Applying change to NONE SpaceTypes')
    elsif !space_type_handle.empty?
      # Single SpaceType handle found, check if object is good
      if !space_type_object.get.to_SpaceType.empty?
        runner.registerInfo("Applying change to #{space_type_object.get.name} SpaceType")
        space_types << space_type_object.get.to_SpaceType.get
      else
        runner.registerError("SpaceType with handle #{space_type_handle} could not be found.")
      end
    else
      runner.registerError('SpaceType handle is empty.')
      return false
    end

    # setup spaces
    if space_handle == building_handle
      # Use ALL Spaces
      runner.registerInfo('Applying change to ALL Spaces')
      spaces = model.getSpaces
    elsif space_handle == 0.to_s
      # Spaces set to NONE so do nothing
      runner.registerInfo('Applying change to NONE Spaces')
    elsif !space_handle.empty?
      # Single Space handle found, check if object is good
      if !space_object.get.to_Space.empty?
        runner.registerInfo("Applying change to #{space_object.get.name} Space")
        spaces << space_object.get.to_Space.get
      else
        runner.registerError("Space with handle #{space_handle} could not be found.")
      end
    else
      runner.registerError('Space handle is empty.')
      return false
    end

    altered_people_definitions = []
    altered_infiltration_objects = []
    altered_outdoor_air_objects = []
    altered_internalmass_definitions = []
    altered_lights_definitions = []
    altered_luminaires_definitions = []
    altered_electric_equip_definitions = []
    altered_gas_equip_definitions = []
    altered_other_equip_definitions = []

    # report initial condition of model
    runner.registerInitialCondition("Applying Variable % Changes to #{space_types.size} space types and #{spaces.size} spaces.")
    runner.registerInfo("Applying Variable % Changes to #{space_types.size} space types.")

    # loop through space types
    space_types.each do |space_type|
      # modify lights
      space_type.lights.each do |light|
        equip_def = light.lightsDefinition
        # get and alter multiplier
        if !altered_lights_definitions.include? equip_def.handle.to_s
          if equip_def.lightingLevel.is_initialized
            runner.registerInfo("Applying #{lights_perc_change} % Change to #{equip_def.name.get} LightingLevel.")
            equip_def.setLightingLevel(equip_def.lightingLevel.get + equip_def.lightingLevel.get * lights_perc_change * 0.01)
          end
          if equip_def.wattsperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{lights_perc_change} % Change to #{equip_def.name.get} wattsperSpaceFloorArea.")
            equip_def.setWattsperSpaceFloorArea(equip_def.wattsperSpaceFloorArea.get + equip_def.wattsperSpaceFloorArea.get * lights_perc_change * 0.01)
          end
          if equip_def.wattsperPerson.is_initialized
            runner.registerInfo("Applying #{lights_perc_change} % Change to #{equip_def.name.get} wattsperPerson.")
            equip_def.setWattsperPerson(equip_def.wattsperPerson.get + equip_def.wattsperPerson.get * lights_perc_change * 0.01)
          end
          # update hash and change name
          change_name(equip_def, lights_perc_change)
          altered_lights_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify luminaire
      space_type.luminaires.each do |light|
        equip_def = light.luminaireDefinition
        # get and alter multiplier
        if !altered_luminaires_definitions.include? equip_def.handle.to_s
          runner.registerInfo("Applying #{luminaire_perc_change} % Change to #{equip_def.name.get} LightingPower.")
          equip_def.setLightingPower(equip_def.lightingPower + equip_def.lightingPower * luminaire_perc_change * 0.01)
          # update hash and change name
          change_name(equip_def, luminaire_perc_change)
          altered_luminaires_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify electric equip
      space_type.electricEquipment.each do |equip|
        # get and alter definition
        equip_def = equip.electricEquipmentDefinition
        if !altered_electric_equip_definitions.include? equip_def.handle.to_s
          if equip_def.designLevel.is_initialized
            runner.registerInfo("Applying #{electric_equip_perc_change} % Change to #{equip_def.name.get} DesignLevel.")
            equip_def.setDesignLevel(equip_def.designLevel.get + equip_def.designLevel.get * electric_equip_perc_change * 0.01)
          end
          if equip_def.wattsperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{electric_equip_perc_change} % Change to #{equip_def.name.get} wattsperSpaceFloorArea.")
            equip_def.setWattsperSpaceFloorArea(equip_def.wattsperSpaceFloorArea.get + equip_def.wattsperSpaceFloorArea.get * electric_equip_perc_change * 0.01)
          end
          if equip_def.wattsperPerson.is_initialized
            runner.registerInfo("Applying #{electric_equip_perc_change} % Change to #{equip_def.name.get} wattsperPerson.")
            equip_def.setWattsperPerson(equip_def.wattsperPerson.get + equip_def.wattsperPerson.get * electric_equip_perc_change * 0.01)
          end
          # update hash and change name
          change_name(equip_def, electric_equip_perc_change)
          altered_electric_equip_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify gas equip
      space_type.gasEquipment.each do |equip|
        # get and alter definition
        equip_def = equip.gasEquipmentDefinition
        if !altered_gas_equip_definitions.include? equip_def.handle.to_s
          if equip_def.designLevel.is_initialized
            runner.registerInfo("Applying #{gas_equip_perc_change} % Change to  #{equip_def.name.get} designlevel.")
            equip_def.setDesignLevel(equip_def.designLevel.get + equip_def.designLevel.get * gas_equip_perc_change * 0.01)
          end
          if equip_def.wattsperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{gas_equip_perc_change} % Change to  #{equip_def.name.get} WattsperSpaceFloorArea.")
            equip_def.setWattsperSpaceFloorArea(equip_def.wattsperSpaceFloorArea.get + equip_def.wattsperSpaceFloorArea.get * gas_equip_perc_change * 0.01)
          end
          if equip_def.wattsperPerson.is_initialized
            runner.registerInfo("Applying #{gas_equip_perc_change} % Change to  #{equip_def.name.get} WattsperPerson.")
            equip_def.setWattsperPerson(equip_def.wattsperPerson.get + equip_def.wattsperPerson.get * gas_equip_perc_change * 0.01)
          end
          # update hash and change name
          change_name(equip_def, gas_equip_perc_change)
          altered_gas_equip_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify other equip
      space_type.otherEquipment.each do |equip|
        # get and alter definition
        equip_def = equip.otherEquipmentDefinition
        if !altered_other_equip_definitions.include? equip_def.handle.to_s
          if equip_def.designLevel.is_initialized
            runner.registerInfo("Applying #{other_equip_perc_change} % Change to #{equip_def.name.get} designLevel.")
            equip_def.setDesignLevel(equip_def.designLevel.get + equip_def.designLevel.get * other_equip_perc_change * 0.01)
          end
          if equip_def.wattsperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{other_equip_perc_change} % Change to #{equip_def.name.get} wattsperSpaceFloorArea.")
            equip_def.setWattsperSpaceFloorArea(equip_def.wattsperSpaceFloorArea.get + equip_def.wattsperSpaceFloorArea.get * other_equip_perc_change * 0.01)
          end
          if equip_def.wattsperPerson.is_initialized
            runner.registerInfo("Applying #{other_equip_perc_change} % Change to #{equip_def.name.get} wattsperPerson.")
            equip_def.setWattsperPerson(equip_def.wattsperPerson.get + equip_def.wattsperPerson.get * other_equip_perc_change * 0.01)
          end
          # update hash and change name
          change_name(equip_def, other_equip_perc_change)
          altered_other_equip_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify occupancy
      space_type.people.each do |people_inst|
        # get and alter definition
        people_def = people_inst.peopleDefinition
        if !altered_people_definitions.include? people_def.handle.to_s
          if people_def.peopleperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{people_perc_change} % Change to #{people_def.name.get} PeopleperSpaceFloorArea.")
            people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get + people_def.peopleperSpaceFloorArea.get * people_perc_change * 0.01)
          end
          if people_def.numberofPeople.is_initialized
            runner.registerInfo("Applying #{people_perc_change} % Change to #{people_def.name.get} numberofPeople.")
            people_def.setNumberofPeople(people_def.numberofPeople.get + people_def.numberofPeople.get * people_perc_change * 0.01)
          end
          if people_def.spaceFloorAreaperPerson.is_initialized
            runner.registerInfo("Applying #{people_perc_change} % Change to #{people_def.name.get} spaceFloorAreaperPerson.")
            people_def.setSpaceFloorAreaperPerson(people_def.spaceFloorAreaperPerson.get + people_def.spaceFloorAreaperPerson.get * people_perc_change * 0.01)
          end
          # update hash and change name
          change_name(people_def, people_perc_change)
          altered_people_definitions << people_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{people_def.name.get}")
        end
      end

      # modify infiltration
      space_type.spaceInfiltrationDesignFlowRates.each do |infiltration|
        if !altered_infiltration_objects.include? infiltration.handle.to_s
          if infiltration.flowperExteriorSurfaceArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} FlowperExteriorSurfaceArea.")
            infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get + infiltration.flowperExteriorSurfaceArea.get * infil_perc_change * 0.01)
          end
          if infiltration.airChangesperHour.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} AirChangesperHour.")
            infiltration.setAirChangesperHour(infiltration.airChangesperHour.get + infiltration.airChangesperHour.get * infil_perc_change * 0.01)
          end
          if infiltration.designFlowRate.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} designFlowRate.")
            infiltration.setDesignFlowRate(infiltration.designFlowRate.get + infiltration.designFlowRate.get * infil_perc_change * 0.01)
          end
          if infiltration.flowperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} flowperSpaceFloorArea.")
            infiltration.setFlowperSpaceFloorArea(infiltration.flowperSpaceFloorArea.get + infiltration.flowperSpaceFloorArea.get * infil_perc_change * 0.01)
          end
          if infiltration.flowperExteriorWallArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} flowperExteriorWallArea.")
            infiltration.setFlowperExteriorWallArea(infiltration.flowperExteriorWallArea.get + infiltration.flowperExteriorWallArea.get * infil_perc_change * 0.01)
          end
          # add to hash and change name
          change_name(infiltration, infil_perc_change)
          altered_infiltration_objects << infiltration.handle.to_s
        else
          runner.registerInfo("Skipping change to #{infiltration.name.get}")
        end
      end

      # modify outdoor air
      if space_type.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space_type.designSpecificationOutdoorAir.get
        # alter values if not already done
        if !altered_outdoor_air_objects.include? outdoor_air.handle.to_s
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperPerson.")
          outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson + outdoor_air.outdoorAirFlowperPerson * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperFloorArea.")
          outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea + outdoor_air.outdoorAirFlowperFloorArea * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowAirChangesperHour.")
          outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour + outdoor_air.outdoorAirFlowAirChangesperHour * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowRate.")
          outdoor_air.setOutdoorAirFlowRate(outdoor_air.outdoorAirFlowRate + outdoor_air.outdoorAirFlowRate * vent_perc_change * 0.01)
          # add to hash and change name
          change_name(outdoor_air, vent_perc_change)
          altered_outdoor_air_objects << outdoor_air.handle.to_s
        else
          runner.registerInfo("Skipping change to #{outdoor_air.name.get}")
        end
      end

      # modify internal mass
      space_type.internalMass.each do |internalmass|
        # get and alter definition
        internalmass_def = internalmass.internalMassDefinition
        if !altered_internalmass_definitions.include? internalmass_def.handle.to_s
          if internalmass_def.surfaceAreaperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceAreaperSpaceFloorArea.")
            internalmass_def.setSurfaceAreaperSpaceFloorArea(internalmass_def.surfaceAreaperSpaceFloorArea.get + internalmass_def.surfaceAreaperSpaceFloorArea.get * mass_perc_change * 0.01)
          end
          if internalmass_def.surfaceArea.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceArea.")
            internalmass_def.setSurfaceArea(internalmass_def.surfaceArea.get + internalmass_def.surfaceArea.get * mass_perc_change * 0.01)
          end
          if internalmass_def.surfaceAreaperPerson.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceAreaperPerson.")
            internalmass_def.setSurfaceAreaperPerson(internalmass_def.surfaceAreaperPerson.get + internalmass_def.surfaceAreaperPerson.get * mass_perc_change * 0.01)
          end
          # update hash and change name
          change_name(internalmass_def, mass_perc_change)
          altered_internalmass_definitions << internalmass_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{internalmass_def.name.get}")
        end
      end
    end # end space_type loop

    runner.registerInfo("altered_lights_definitions: #{altered_lights_definitions}")
    runner.registerInfo("altered_luminaires_definitions: #{altered_luminaires_definitions}")
    runner.registerInfo("altered_electric_equip_definitions: #{altered_electric_equip_definitions}")
    runner.registerInfo("altered_gas_equip_definitions: #{altered_gas_equip_definitions}")
    runner.registerInfo("altered_other_equip_definitions: #{altered_other_equip_definitions}")
    runner.registerInfo("altered_people_definitions: #{altered_people_definitions}")
    runner.registerInfo("altered_infiltration_objects: #{altered_infiltration_objects}")
    runner.registerInfo("altered_outdoor_air_objects: #{altered_outdoor_air_objects}")
    runner.registerInfo("altered_internalmass_definitions: #{altered_internalmass_definitions}")

    # report initial condition of model
    runner.registerInfo("Applying Variable % Changes to #{spaces.size} spaces.")

    # loop through space types
    spaces.each do |space|
      # modify lights
      space.lights.each do |light|
        equip_def = light.lightsDefinition
        # get and alter definition
        if !altered_lights_definitions.include? equip_def.handle.to_s
          if equip_def.lightingLevel.is_initialized
            runner.registerInfo("Applying #{lights_perc_change} % Change to #{equip_def.name.get} LightingLevel.")
            equip_def.setLightingLevel(equip_def.lightingLevel.get + equip_def.lightingLevel.get * lights_perc_change * 0.01)
          end
          if equip_def.wattsperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{lights_perc_change} % Change to #{equip_def.name.get} wattsperSpaceFloorArea.")
            equip_def.setWattsperSpaceFloorArea(equip_def.wattsperSpaceFloorArea.get + equip_def.wattsperSpaceFloorArea.get * lights_perc_change * 0.01)
          end
          if equip_def.wattsperPerson.is_initialized
            runner.registerInfo("Applying #{lights_perc_change} % Change to #{equip_def.name.get} wattsperPerson.")
            equip_def.setWattsperPerson(equip_def.wattsperPerson.get + equip_def.wattsperPerson.get * lights_perc_change * 0.01)
          end
          # update hash and change name
          change_name(equip_def, lights_perc_change)
          altered_lights_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify luminaire
      space.luminaires.each do |light|
        equip_def = light.luminaireDefinition
        # get and alter definition
        if !altered_luminaires_definitions.include? equip_def.handle.to_s
          runner.registerInfo("Applying #{luminaire_perc_change} % Change to #{equip_def.name.get} LightingPower.")
          equip_def.setLightingPower(equip_def.lightingPower + equip_def.lightingPower * luminaire_perc_change * 0.01)
          # update hash and change name
          change_name(equip_def, luminaire_perc_change)
          altered_luminaires_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify electric equip
      space.electricEquipment.each do |equip|
        # get and alter definition
        equip_def = equip.electricEquipmentDefinition
        if !altered_electric_equip_definitions.include? equip_def.handle.to_s
          if equip_def.designLevel.is_initialized
            runner.registerInfo("Applying #{electric_equip_perc_change} % Change to #{equip_def.name.get} DesignLevel.")
            equip_def.setDesignLevel(equip_def.designLevel.get + equip_def.designLevel.get * electric_equip_perc_change * 0.01)
          end
          if equip_def.wattsperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{electric_equip_perc_change} % Change to #{equip_def.name.get} wattsperSpaceFloorArea.")
            equip_def.setWattsperSpaceFloorArea(equip_def.wattsperSpaceFloorArea.get + equip_def.wattsperSpaceFloorArea.get * electric_equip_perc_change * 0.01)
          end
          if equip_def.wattsperPerson.is_initialized
            runner.registerInfo("Applying #{electric_equip_perc_change} % Change to #{equip_def.name.get} wattsperPerson.")
            equip_def.setWattsperPerson(equip_def.wattsperPerson.get + equip_def.wattsperPerson.get * electric_equip_perc_change * 0.01)
          end
          # update hash and change name
          change_name(equip_def, electric_equip_perc_change)
          altered_electric_equip_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify gas equip
      space.gasEquipment.each do |equip|
        # get and alter definition
        equip_def = equip.gasEquipmentDefinition
        if !altered_gas_equip_definitions.include? equip_def.handle.to_s
          if equip_def.designLevel.is_initialized
            runner.registerInfo("Applying #{gas_equip_perc_change} % Change to  #{equip_def.name.get} designlevel.")
            equip_def.setDesignLevel(equip_def.designLevel.get + equip_def.designLevel.get * gas_equip_perc_change * 0.01)
          end
          if equip_def.wattsperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{gas_equip_perc_change} % Change to  #{equip_def.name.get} WattsperSpaceFloorArea.")
            equip_def.setWattsperSpaceFloorArea(equip_def.wattsperSpaceFloorArea.get + equip_def.wattsperSpaceFloorArea.get * gas_equip_perc_change * 0.01)
          end
          if equip_def.wattsperPerson.is_initialized
            runner.registerInfo("Applying #{gas_equip_perc_change} % Change to  #{equip_def.name.get} WattsperPerson.")
            equip_def.setWattsperPerson(equip_def.wattsperPerson.get + equip_def.wattsperPerson.get * gas_equip_perc_change * 0.01)
          end
          # update hash and change name
          change_name(equip_def, gas_equip_perc_change)
          altered_gas_equip_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify other equip
      space.otherEquipment.each do |equip|
        # get and alter definition
        equip_def = equip.otherEquipmentDefinition
        if !altered_other_equip_definitions.include? equip_def.handle.to_s
          if equip_def.designLevel.is_initialized
            runner.registerInfo("Applying #{other_equip_perc_change} % Change to #{equip_def.name.get} designLevel.")
            equip_def.setDesignLevel(equip_def.designLevel.get + equip_def.designLevel.get * other_equip_perc_change * 0.01)
          end
          if equip_def.wattsperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{other_equip_perc_change} % Change to #{equip_def.name.get} wattsperSpaceFloorArea.")
            equip_def.setWattsperSpaceFloorArea(equip_def.wattsperSpaceFloorArea.get + equip_def.wattsperSpaceFloorArea.get * other_equip_perc_change * 0.01)
          end
          if equip_def.wattsperPerson.is_initialized
            runner.registerInfo("Applying #{other_equip_perc_change} % Change to #{equip_def.name.get} wattsperPerson.")
            equip_def.setWattsperPerson(equip_def.wattsperPerson.get + equip_def.wattsperPerson.get * other_equip_perc_change * 0.01)
          end
          # update hash and change name
          change_name(equip_def, other_equip_perc_change)
          altered_other_equip_definitions << equip_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{equip_def.name.get}")
        end
      end

      # modify occupancy
      space.people.each do |people_inst|
        # get and alter definition
        people_def = people_inst.peopleDefinition
        if !altered_people_definitions.include? people_def.handle.to_s
          if people_def.peopleperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{people_perc_change} % Change to #{people_def.name.get} PeopleperSpaceFloorArea.")
            people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get + people_def.peopleperSpaceFloorArea.get * people_perc_change * 0.01)
          end
          if people_def.numberofPeople.is_initialized
            runner.registerInfo("Applying #{people_perc_change} % Change to #{people_def.name.get} numberofPeople.")
            people_def.setNumberofPeople(people_def.numberofPeople.get + people_def.numberofPeople.get * people_perc_change * 0.01)
          end
          if people_def.spaceFloorAreaperPerson.is_initialized
            runner.registerInfo("Applying #{people_perc_change} % Change to #{people_def.name.get} spaceFloorAreaperPerson.")
            people_def.setSpaceFloorAreaperPerson(people_def.spaceFloorAreaperPerson.get + people_def.spaceFloorAreaperPerson.get * people_perc_change * 0.01)
          end
          # update hash and change name
          change_name(people_def, people_perc_change)
          altered_people_definitions << people_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{people_def.name.get}")
        end
      end

      # modify infiltration
      space.spaceInfiltrationDesignFlowRates.each do |infiltration|
        if !altered_infiltration_objects.include? infiltration.handle.to_s
          if infiltration.flowperExteriorSurfaceArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} FlowperExteriorSurfaceArea.")
            infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get + infiltration.flowperExteriorSurfaceArea.get * infil_perc_change * 0.01)
          end
          if infiltration.airChangesperHour.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} AirChangesperHour.")
            infiltration.setAirChangesperHour(infiltration.airChangesperHour.get + infiltration.airChangesperHour.get * infil_perc_change * 0.01)
          end
          if infiltration.designFlowRate.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} designFlowRate.")
            infiltration.setDesignFlowRate(infiltration.designFlowRate.get + infiltration.designFlowRate.get * infil_perc_change * 0.01)
          end
          if infiltration.flowperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} flowperSpaceFloorArea.")
            infiltration.setFlowperSpaceFloorArea(infiltration.flowperSpaceFloorArea.get + infiltration.flowperSpaceFloorArea.get * infil_perc_change * 0.01)
          end
          if infiltration.flowperExteriorWallArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} flowperExteriorWallArea.")
            infiltration.setFlowperExteriorWallArea(infiltration.flowperExteriorWallArea.get + infiltration.flowperExteriorWallArea.get * infil_perc_change * 0.01)
          end
          # add to hash and change name
          change_name(infiltration, infil_perc_change)
          altered_infiltration_objects << infiltration.handle.to_s
        else
          runner.registerInfo("Skipping change to #{infiltration.name.get}")
        end
      end

      # modify outdoor air
      if space.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space.designSpecificationOutdoorAir.get
        # alter values if not already done
        if !altered_outdoor_air_objects.include? outdoor_air.handle.to_s
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperPerson.")
          outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson + outdoor_air.outdoorAirFlowperPerson * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperFloorArea.")
          outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea + outdoor_air.outdoorAirFlowperFloorArea * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowAirChangesperHour.")
          outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour + outdoor_air.outdoorAirFlowAirChangesperHour * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowRate.")
          outdoor_air.setOutdoorAirFlowRate(outdoor_air.outdoorAirFlowRate + outdoor_air.outdoorAirFlowRate * vent_perc_change * 0.01)
          # add to hash and change name
          change_name(outdoor_air, vent_perc_change)
          altered_outdoor_air_objects << outdoor_air.handle.to_s
        else
          runner.registerInfo("Skipping change to #{outdoor_air.name.get}")
        end
      end

      # modify internal mass
      space.internalMass.each do |internalmass|
        # get and alter definition
        internalmass_def = internalmass.internalMassDefinition
        if !altered_internalmass_definitions.include? internalmass_def.handle.to_s
          if internalmass_def.surfaceAreaperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceAreaperSpaceFloorArea.")
            internalmass_def.setSurfaceAreaperSpaceFloorArea(internalmass_def.surfaceAreaperSpaceFloorArea.get + internalmass_def.surfaceAreaperSpaceFloorArea.get * mass_perc_change * 0.01)
          end
          if internalmass_def.surfaceArea.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceArea.")
            internalmass_def.setSurfaceArea(internalmass_def.surfaceArea.get + internalmass_def.surfaceArea.get * mass_perc_change * 0.01)
          end
          if internalmass_def.surfaceAreaperPerson.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceAreaperPerson.")
            internalmass_def.setSurfaceAreaperPerson(internalmass_def.surfaceAreaperPerson.get + internalmass_def.surfaceAreaperPerson.get * mass_perc_change * 0.01)
          end
          # update hash and change name
          change_name(internalmass_def, mass_perc_change)
          altered_internalmass_definitions << internalmass_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{internalmass_def.name.get}")
        end
      end
    end # end spaces loop

    runner.registerInfo("altered_lights_definitions: #{altered_lights_definitions}")
    runner.registerInfo("altered_luminaires_definitions: #{altered_luminaires_definitions}")
    runner.registerInfo("altered_electric_equip_definitions: #{altered_electric_equip_definitions}")
    runner.registerInfo("altered_gas_equip_definitions: #{altered_gas_equip_definitions}")
    runner.registerInfo("altered_other_equip_definitions: #{altered_other_equip_definitions}")
    runner.registerInfo("altered_people_definitions: #{altered_people_definitions}")
    runner.registerInfo("altered_infiltration_objects: #{altered_infiltration_objects}")
    runner.registerInfo("altered_outdoor_air_objects: #{altered_outdoor_air_objects}")
    runner.registerInfo("altered_internalmass_definitions: #{altered_internalmass_definitions}")

    # na if nothing in model to look at
    if altered_lights_definitions.size + altered_luminaires_definitions.size + altered_electric_equip_definitions.size + altered_gas_equip_definitions.size + altered_other_equip_definitions.size + altered_people_definitions.size + altered_infiltration_objects.size + altered_outdoor_air_objects.size + altered_internalmass_definitions.size == 0
      runner.registerAsNotApplicable('No objects to alter were found in the model')
      return true
    end

    # report final condition of model
    runner.registerFinalCondition("#{altered_lights_definitions.size} light objects were altered. #{altered_luminaires_definitions.size} luminaire objects were altered. #{altered_electric_equip_definitions.size} electric Equipment objects were altered. #{altered_gas_equip_definitions.size} gas Equipment objects were altered. #{altered_other_equip_definitions.size} otherEquipment objects were altered. #{altered_people_definitions.size} people definitions were altered. #{altered_infiltration_objects.size} infiltration objects were altered. #{altered_outdoor_air_objects.size} ventilation objects were altered. #{altered_internalmass_definitions.size} internal mass objects were altered.")

    true
  end
end

# register the measure to be used by the application
GeneralCalibrationMeasurePercentChange.new.registerWithApplication
