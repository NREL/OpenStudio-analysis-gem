# OpenStudio::Analysis::Workflow configured the list of measures to run and in what order
module OpenStudio
  module Analysis
    class Workflow
      attr_reader :items
      # allow users to access the items via the measures attribute accessor
      alias :measures :items

      # Create an instance of the OpenStudio::Analysis::Workflow
      #
      # @return [Object] An OpenStudio::Analysis::Workflow object
      def initialize
        @items = []

      end

      # Remove all the items in the workflow
      def clear
        @items.clear
      end

      # Add a measure to the workflow from a path. Inside the path it is expecting to have a measure.json file
      # if not, the BCL gem is used to create the measure.json file.
      #
      # @params instance_name [String] The name of the instance. This allows for multiple measures to be added to the worklow with unique names
      # @params path_to_measure [String] The path to the measure to load
      # @return [Boolean] true/false on weather the measure was added
      def add_measure_from_path(instance_name, instance_display_name, path_to_measure)
        measure_filename = 'measure.rb'
        if File.exist?(path_to_measure) && File.file?(path_to_measure)
          measure_filename = File.basename(path_to_measure)
          path_to_measure = File.dirname(path_to_measure)
        end

        if Dir.exist?(path_to_measure) && File.directory?(path_to_measure)
          b = BCL::ComponentMethods.new
          measure_hash = nil
          unless File.exist?(File.join(path_to_measure, 'measure.json'))
            measure_hash = b.parse_measure_file(nil, File.join(path_to_measure, measure_filename))
            File.open(File.join(path_to_measure, 'measure.json'), 'w') { |f| f << JSON.pretty_generate(measure_hash) }
            warn("#{path_to_measure}: measure.json not found, will parse measure file using Bcl bem")
          end

          if measure_hash
            @items << OpenStudio::Analysis::WorkflowStep.from_measure_hash(instance_name, instance_display_name, path_to_measure, measure_hash)
          elsif File.exist?(File.join(path_to_measure, 'measure.json'))
            @items << OpenStudio::Analysis::WorkflowStep.from_measure_hash(
                instance_name,
                instance_display_name,
                path_to_measure,
                JSON.parse(File.read(File.join(path_to_measure, 'measure.json')), symbolize_names: true)
            )
          else
            fail "measure.json was not found and was not automatically created"
          end
        else
          fail "could not find measure to add to workflow #{path_to_measure}"
        end

        @items.last
      end

      # Find the measure by its instance name
      #
      # @params instance_name [String] instance name of the measure
      def find_measure(instance_name)
        #@measures[""]
      end

      # Save the workflow to a hash object
      def to_hash
        @items.map{|i| i.to_hash}
      end

      # Save the workflow to a JSON string
      #
      # @return [String] JSON formatted string
      def to_json
        JSON.pretty_generate(self.to_hash)
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

