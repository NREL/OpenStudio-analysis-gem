# OpenStudio::Analysis::WorkflowStep is a class container for storing a measure. The generic name of step may be used later
# to include a workflow step on running energyplus, radiance, etc.
module OpenStudio
  module Analysis
    class WorkflowStep
      attr_accessor :type
      attr_accessor :name
      attr_accessor :display_name

      attr_accessor :measure_definition_class_name
      attr_accessor :measure_definition_directory
      attr_accessor :measure_definition_display_name
      attr_accessor :measure_definition_name
      attr_accessor :measure_definition_name_xml
      attr_accessor :measure_definition_uuid
      attr_accessor :measure_definition_version_uuid
      attr_accessor :arguments

      # Create an instance of the OpenStudio::Analysis::WorkflowStep
      #
      # @return [Object] An OpenStudio::Analysis::WorkflowStep object
      def initialize
        @name = ''
        @display_name = ''

        # The type of item being added (RubyMeasure, EnergyPlusMeasure, ...)
        @type = nil

        @measure_definition_class_name = nil
        @measure_definition_directory = nil
        @measure_definition_display_name = nil
        @measure_definition_name = nil
        @measure_definition_name_xml = nil
        @measure_definition_uuid = nil
        @measure_definition_version_uuid = nil
        @arguments = []

      end

      # Convert the class into a hash. TODO: Make this smart based on the :type eventually
      #
      # @return [Hash] Returns the hash
      def to_hash(*a)
        hash = {}
        self.instance_variables.each do |var|
          if var.to_s == '@type'
            hash[:measure_type] = self.instance_variable_get(var)
          else
            hash[var.to_s.delete("@")] = self.instance_variable_get(var)
          end
        end
        hash
      end
      
      # Read the workflow item from a measure hash
      #
      # @param instance_name [String] Machine name of the instance
      # @param instance_display_name [String] Display name of the instance
      # @param path_to_measure [String] The path to the measure, not the measure itself
      # @param hash [String] Measure hash in the form of the measure.json format (from the Analysis Spreadsheet project)
      # @return [Object] Returns the OpenStudio::Analysis::WorkflowStep
      def self.from_measure_hash(instance_name, instance_display_name, path_to_measure, hash)
        # TODO: Validate the hash

        # map the BCL hash format into the OpenStudio WorkflowStep format
        s = OpenStudio::Analysis::WorkflowStep.new

        # add the instance and display name
        s.name = instance_name
        s.display_name = instance_display_name

        # definition of the measure
        s.measure_definition_class_name = hash[:classname]
        s.measure_definition_directory = path_to_measure
        s.measure_definition_display_name = hash[:display_name]
        s.measure_definition_name = hash[:name]
        s.measure_definition_name_xml = hash[:name_xml]
        s.measure_definition_uuid = hash[:uid]
        s.measure_definition_version_uuid = hash[:version_id]

        s.type = hash[:measure_type] # this is actually the measure type
        if hash[:arguments]
          hash[:arguments].each do |arg|
            s.arguments << {
                display_name: arg[:display_name],
                display_name_short: arg[:display_name],
                name: arg[:local_variable],
                value_type: arg[:variable_type].downcase,
                default_value: arg[:default_value]
            }
          end
        end

        s
      end
    end
  end
end

