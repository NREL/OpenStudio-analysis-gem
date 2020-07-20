class ExampleMeasure < OpenStudio::Measure::ModelMeasure
  # not a real measure
end # end the measure

ExampleMeasure.new.registerWithApplication
