# OpenStudio::Analysis::Workflow configured the list of measures to run and in what order
module OpenStudio
  module Analysis
    class Workflow

      # Create an instance of the OpenStudio::Analysis::Workflow
      #
      # @return [Object] An OpenStudio::Analysis::Workflow object
      def initialize

      end

      # Read the Workflow description from a persisted file. The format at the moment is the current analysis.json
      #
      # @params filename [String] Path to file with the analysis.json to load
      # @return [Object] Return an instance of the workflow object
      def self.from_file(filename)
        if File.exist? filename
          j = JSON.parse(File.read(filename), symbolize_names: true)
          puts j
        else
          fail "Could not find workflow file #{filename}"
        end

        o = OpenStudio::Analysis::Workflow.new
        # put the JSON into the right format
        o
      end

    end
  end
end

