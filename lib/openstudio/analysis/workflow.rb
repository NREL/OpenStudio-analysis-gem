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
      # @return [Object] The WorkflowStep with the instance_name
      def find_measure(instance_name)
        @items.find{ |i| i.name == instance_name}
      end

      # Return all the variables in the analysis as an array. The list that is returned is read only.
      #
      # @return [Array] All variables in the workflow
      def all_variables
        @items.map{|i| i.variables }.flatten


      end

      # Save the workflow to a hash object
      def to_hash(version = 1)
        h = nil
        if version == 1
          h = @items.map{|i| i.to_hash(version)}
        else
          fail "Version #{version} not yet implemented for to_hash"
        end

        h
      end

      # Save the workflow to a JSON string
      #
      # @return [String] JSON formatted string
      def to_json(version = 1)
        if version == 1
          JSON.pretty_generate(self.to_hash(version))
        else
          fail "Version #{version} not yet implemented for to_json"
        end
      end

      # Read the Workflow description from a persisted file. The format at the moment is the current analysis.json
      #
      # @params filename [String] Path to file with the analysis.json to load
      # @return [Object] Return an instance of the workflow object
      def self.from_file(filename)
        if File.exist? filename
          j = JSON.parse(File.read(filename), symbolize_names: true)

          # get the version of the file
          file_format_version = j[:file_format_version] ? j[:file_format_version] : 1

          puts "Parsing file version #{file_format_version}"

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

