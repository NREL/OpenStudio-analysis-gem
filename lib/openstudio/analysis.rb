# OpenStudio::Analysis Module instantiates versions of formulations
module OpenStudio
  module Analysis
    # Create a new analysis
    def self.create(display_name)
      OpenStudio::Analysis::Formulation.new(display_name)
    end

    # Load the analysis json or from a file. If this is a json then it must have
    # symbolized keys
    def self.load(h)
      h = MultiJson.load(h, symbolize_keys: true) unless h.is_a? Hash
      OpenStudio::Analysis::Formulation.from_hash h
    end

    # Load an analysis from excel. This will create an array of analyses because
    # excel can create more than one analyses
    def self.from_excel(filename)
      excel = OpenStudio::Analysis::Translator::Excel.new(filename)
      excel.process
      excel.analyses
    end
  end
end
