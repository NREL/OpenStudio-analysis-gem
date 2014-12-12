# OpenStudio::Analysis::Workflow configured the list of measures to run and in what order
module OpenStudio
  module Analysis
    class Workflow
      attr_reader :measures

      # Create an instance of the OpenStudio::Analysis::Workflow
      #
      # @return [Object] An OpenStudio::Analysis::Workflow object
      def initialize
        @measures = []

      end

      # Add a measure to the workflow from a path. Inside the path it is expecting to have a measure.json file
      # if not, the BCL gem is used to create the measure.json file
      #
      # @params path_to_measure [String] The path to the measure to load
      # @return [Boolean] true/false on weather the measure was added
      def add_measure_from_path(path_to_measure)
        if Dir.exist?(path_to_measure) && File.directory?(path_to_measure)
          b = BCL::ComponentMethods.new
          measure_hash = nil
          unless File.exist?(File.join(path_to_measure, 'measure.json'))
            measure_hash = b.parse_measure_file(nil, File.join(path_to_measure, 'measure.rb'))
            File.open(File.join(path_to_measure, 'measure.json'), 'w') { |f| f << JSON.pretty_generate(measure_hash)}
            warn("#{path_to_measure}: measure.json not found, will parse measure file using Bcl bem")
          end

          if measure_hash
            @measures << measure_hash
          elsif File.exist?(File.join(path_to_measure, 'measure.json'))
            @measures << JSON.parse(File.read(File.join(path_to_measure, 'measure.json')))
          else
            fail "measure.json was not found and was not automatically created"
          end
        else
          fail "could not find measure to add to workflow #{path_to_measure}"
        end

        @measures.last
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

