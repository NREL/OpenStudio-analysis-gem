# OpenStudio::Analysis Module instantiates versions of formulations
module OpenStudio
  module Analysis
    def self.create(display_name)
      OpenStudio::Analysis::Formulation.new(display_name)
    end
  end
end
