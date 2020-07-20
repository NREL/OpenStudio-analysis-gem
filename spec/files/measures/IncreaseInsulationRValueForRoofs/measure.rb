# start the measure
class IncreaseInsulationRValueForRoofs < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see
  def name
    'Increase R-value of Insulation for Roofs to a Specific Value'
  end

  # define the arguments that the user will input
  def arguments(_model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    return true
  end # end the run method
end # end the measure

# this allows the measure to be used by the application
IncreaseInsulationRValueForRoofs.new.registerWithApplication
