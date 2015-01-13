# OpenStudio::Analysis::Workflow configured the list of measures to run and in what order
module OpenStudio
  module Analysis
    class Workflow
      attr_reader :items
      # allow users to access the items via the measures attribute accessor
      alias_method :measures, :items

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
      # @params instance_name [String] The name of the instance. This allows for multiple measures to be added to the workflow with unique names
      # @params instance_display_name [String] The display name of the instance. This allows for multiple measures to be added to the workflow with unique names
      # @param local_path_to_measure [String] This is the local path to the measure directory, relative or absolute. It is used when zipping up all the measures.
      # @return [Object] Returns the measure that was added as an OpenStudio::AnalysisWorkflowStep object
      def add_measure_from_path(instance_name, instance_display_name, local_path_to_measure)
        measure_filename = 'measure.rb'
        if File.exist?(local_path_to_measure) && File.file?(local_path_to_measure)
          measure_filename = File.basename(local_path_to_measure)
          local_path_to_measure = File.dirname(local_path_to_measure)
        end

        if Dir.exist?(local_path_to_measure) && File.directory?(local_path_to_measure)
          # Watch out for namespace conflicts (use ::BCL)
          b = ::BCL::ComponentMethods.new
          measure_hash = nil
          unless File.exist?(File.join(local_path_to_measure, 'measure.json'))
            measure_hash = b.parse_measure_file(nil, File.join(local_path_to_measure, measure_filename))
            File.open(File.join(local_path_to_measure, 'measure.json'), 'w') { |f| f << JSON.pretty_generate(measure_hash) }
            warn("measure.json not found in #{local_path_to_measure}, will parse measure file using BCL gem")
          end

          if measure_hash.nil? && File.exist?(File.join(local_path_to_measure, 'measure.json'))
            measure_hash = JSON.parse(File.read(File.join(local_path_to_measure, 'measure.json')), symbolize_names: true)
          elsif measure_hash.nil?
            fail 'measure.json was not found and was not automatically created'
          end

          add_measure(instance_name, instance_display_name, local_path_to_measure, measure_hash)
        else
          fail "could not find measure to add to workflow #{local_path_to_measure}"
        end

        @items.last
      end

      # Add a measure from the custom hash format without reading the measure.rb or measure.json file
      #
      # @params instance_name [String] The name of the instance. This allows for multiple measures to be added to the workflow with unique names
      # @params instance_display_name [String] The display name of the instance. This allows for multiple measures to be added to the workflow with unique names
      # @param local_path_to_measure [String] This is the local path to the measure directory, relative or absolute. It is used when zipping up all the measures.
      # @param measure_metadata [Hash] Format of the measure.json
      # @return [Object] Returns the measure that was added as an OpenStudio::AnalysisWorkflowStep object
      def add_measure(instance_name, instance_display_name, local_path_to_measure, measure_metadata)
        @items << OpenStudio::Analysis::WorkflowStep.from_measure_hash(instance_name, instance_display_name, local_path_to_measure, measure_metadata)

        @items.last
      end

      # Add a measure from the format that Excel parses into. This is a helper method to map the excel data to the new
      # programmatic interface format
      #
      # @params measure [Hash] The measure in the format of the Excel translator
      # @return [Object] Returns the measure that was added as an OpenStudio::AnalysisWorkflowStep object
      def add_measure_from_excel(measure)
        hash = {}
        hash[:classname] = measure['measure_file_name']
        hash[:name] = measure['name']
        hash[:display_name] = measure['display_name']
        hash[:measure_type] = measure['measure_type']
        hash[:uid] = measure['uid'] ? measure['uid'] : SecureRandom.uuid
        hash[:version_id] = measure['version_id'] ? measure['version_id'] : SecureRandom.uuid

        # map the arguments - this can be a variable or argument, add them all as arguments first
        args = []
        measure['variables'].each do |variable|
          args << {
            local_variable: variable['name'],
            variable_type: variable['type'],
            name: variable['name'],
            display_name: variable['display_name'],
            display_name_short: variable['display_name_short'],
            units: variable['units'],
            default_value: variable['distribution']['static_value'],
            value: variable['distribution']['static_value']
          }
        end
        hash[:arguments] = args

        m = add_measure(measure['name'], measure['display_name'], measure['measure_file_name_directory'], hash)

        measure['variables'].each do |variable|
          next unless variable['variable_type'] == 'variable'

          dist = {
            type: variable['distribution']['type'],
            minimum: variable['distribution']['min'],
            maximum: variable['distribution']['max'],
            mean: variable['distribution']['mean'],
            standard_deviation: variable['distribution']['stddev'],
            values: variable['distribution']['discrete_values'],
            weights: variable['distribution']['discrete_weights'],
            step_size: variable['distribution']['delta_x']
          }
          opt = {
            variable_type: variable['variable_type'],
            variable_display_name_short: variable['display_name_short'],
            static_value: variable['distribution']['static_value']
          }

          m.make_variable(variable['name'], variable['display_name'], dist)
        end
      end

      # Iterate over all the WorkflowItems
      def each
        @items.each { |i| yield i }
      end
      # Find the measure by its instance name
      #
      # @params instance_name [String] instance name of the measure
      # @return [Object] The WorkflowStep with the instance_name
      def find_measure(instance_name)
        @items.find { |i| i.name == instance_name }
      end
      alias_method :find_workflow_step, :find_measure

      # Return all the variables in the analysis as an array. The list that is returned is read only.
      #
      # @return [Array] All variables in the workflow
      def all_variables
        @items.map(&:variables).flatten
      end

      # Save the workflow to a hash object
      def to_hash(version = 1)
        h = nil
        if version == 1
          arr = []
          @items.each_with_index do |item, index|
            temp_h = item.to_hash(version)
            temp_h[:workflow_index] = index

            arr << temp_h
          end

          h = arr
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
          JSON.pretty_generate(to_hash(version))
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
