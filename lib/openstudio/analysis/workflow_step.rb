# OpenStudio::Analysis::WorkflowStep is a class container for storing a measure. The generic name of step may be used later
# to include a workflow step on running EnergyPlus, radiance, etc.
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
        @variables = []
      end

      # Tag a measure's argument as a variable.
      #
      # @param argument_name [String] The instance_name of the measure argument that is to be tagged. This is the same name as the argument's variable in the measure.rb file.
      # @param variable_type [String] What type of variable. Currently only discrete or continuous.
      # @param distribution [Hash] Hash describing the distribution of the variable.
      # @option distribution [String] :type Type of distribution. `discrete`, `uniform`, `triangle`, `normal`, `lognormal`
      # @option distribution [String] :units Units of the variable. This is legacy as previous OpenStudio measures did not specify units separately.
      # @option distribution [String] :minimum Minimum value of the distribution, required for all distributions
      # @option distribution [String] :maximum Maximum value of the distribution, required for all distributions
      # @option distribution [String] :standard_deviation The standard deviation, if the distribution requires it.
      # @option distribution [String] :mode The mean/mode of the distribution (if required)
      # @option distribution [String] :mean Alias for the mode. If this is used it will override the mode
      # @option distribution [String] :relation_to_output How is the variable correlates to the output of interest (for continuous distributions)
      # @option distribution [String] :step_size Minimum step size (delta_x) of the variable (for continuous distributions)
      # @option distribution [String] :values If discrete, then the values to run
      # @option distribution [String] :weights If discrete, then the weights for each of the discrete values, must be the same length as values, and sum to 1. If empty, then it will create this automatically to be uniform.
      # @param variable_type [String] What type of variable, variable or pivot. Typically this is variable.
      # @param options [Hash] Values that define the variable.
      # @option options [String] :variable_type The type of variable, `variable` or `pivot`. By default this is a variable.
      # @option options [String] :variable_display_name_short The short display name of the variable. Will be defaulted to the variable_display_name if not passed
      # @option options [String] :static_value Static/Default value of the variable. If not defined it will use the default value for the argument.
      # @return [Boolean] True / False if it was able to tag the measure argument
      def make_variable(argument_name, variable_display_name, distribution, options = {})
        options = {variable_type: 'variable'}.merge(options)
        a = @arguments.find_all { |a| a[:name] == argument_name }
        distribution[:mode] = distribution[:mean] if distribution[:mean]
        fail "could not find argument_name of #{argument_name} in measure #{self.name}" if a.empty?
        fail "more than one argument with the same name of #{argument_name} in measure #{self.name}" if a.size > 1

        if distribution_valid?(distribution)
          # grab the argument hash
          a = a.first

          # add more information to the argument
          v = {}
          v[:argument] = a
          v[:display_name] = variable_display_name
          v[:display_name_short] = options[:variable_display_name_short] ? options[:variable_display_name_short] : variable_display_name

          v[:type] = distribution[:type]
          v[:units] = distribution[:units] ? distribution[:units] : nil
          v[:minimum] = distribution[:minimum]
          v[:maximum] = distribution[:maximum]
          v[:relation_to_output] = distribution[:relation_to_output] ? distribution[:relation_to_output] : nil
          v[:mode] = distribution[:mode]
          v[:static_value] = distribution[:static_value] if distribution[:static_value]
          # TODO: Static value should be named default value

          if distribution[:type] =~ /discrete/
            v[:weights] = distribution[:weights]
            v[:values] = distribution[:values]
          elsif distribution[:type] =~ /triangle/
            v[:step_size] = distribution[:step_size] ? distribution[:step_size] : nil
          elsif distribution[:type] =~ /normal/
            v[:step_size] = distribution[:step_size] ? distribution[:step_size] : nil
            v[:standard_deviation] = distribution[:standard_deviation]
          end

          @variables << v
        end
        true
      end


      # Convert the class into a hash. TODO: Make this smart based on the :type eventually
      #
      # @return [Hash] Returns the hash
      def to_hash(version = 1, *a)
        hash = {}
        if version == 1
          self.instance_variables.each do |var|
            if var.to_s == '@type'
              hash[:measure_type] = self.instance_variable_get(var)
            elsif var.to_s == '@arguments'
              hash[:arguments] = []
              @arguments.each do |a|
                # This will change in version 2 but right now, if the argument is a variable, then the argument will
                # be in the variables hash, not the arguments hash.
                next unless @variables.find { |v| v[:argument][:name] == a[:name] }.nil?
                hash[:arguments] << a
              end
            elsif var.to_s == '@variables'
              # skip until after looping over instance_variables
            else
              hash[var.to_s.delete("@")] = self.instance_variable_get(var)
            end

            # TODO: warn that we are no longer writing out "variable_type": "RubyContinuousVariable",
            # TODO: iterate over the variables and create UUIDs, or not?
          end

          # fix everything to support the legacy version
          hash[:variables] = @variables

          # Clean up the variables to match the legacy format
          hash[:variables].each_with_index do |v, index|
            v[:variable_type] == 'pivot' ? v[:pivot] = true : v[:variable] = true
            v[:variable] = true
            v[:static_value] = v[:argument][:default_value] unless v[:static_value]

            v[:uncertainty_description] = {}
            v[:uncertainty_description][:type] = v[:type] =~ /uncertain/ ? "#{v[:type]}" : "#{v[:type]}_uncertain"
            warn "Deprecation Warning. In Version 0.5 the _uncertain text will be removed from distribution types: #{v[:uncertainty_description][:type]}"
            warn "Deprecation Warning. RubyContinuousVariable (OpenStudio called this the variable_type) is no longer persisted"

            # This is not neatly coded. This should be a new object that knows how to write itself out.
            v[:uncertainty_description][:attributes] = []
            if v[:type] =~ /discrete/
              new_h = {}
              new_h[:name] = 'discrete'
              new_h[:values_and_weights] = v.delete(:values).zip(v.delete(:weights)).map{|w| {value: w[0], weight: w[1]}}
              v[:uncertainty_description][:attributes] << new_h

              v[:uncertainty_description][:attributes] << { name: 'lower_bounds', value: v[:minimum]}
              v[:uncertainty_description][:attributes] << { name: 'upper_bounds', value: v[:maximum]}
              v[:uncertainty_description][:attributes] << { name: 'modes', value: v[:mode]}
            else

            end

            v[:workflow_index] = index
            warn "Deprecation Warning. workflow_step_type is no longer persisted"

            # remove some remaining items
            v.delete(:type)
            v.delete(:mode) if v[:mode]
          end
          hash[:uuid] = SecureRandom.uuid
          hash[:version_uuid] = SecureRandom.uuid
        else
          fail "Do not know how to create the Hash for Version #{version}"
        end

        hash
      end

      # Read the workflow item from a measure hash.
      #
      # @param instance_name [String] Machine name of the instance
      # @param instance_display_name [String] Display name of the instance
      # @param path_to_measure [String] The path to the measure, not the measure itself
      # @param hash [Hash] Measure hash in the form of the measure.json format (from the Analysis Spreadsheet project)
      # @return [Object] Returns the OpenStudio::Analysis::WorkflowStep
      def self.from_measure_hash(instance_name, instance_display_name, path_to_measure, hash)
        # TODO: Validate the hash

        # verify that the path to the measure is a path and not a file.
        if File.exist?(path_to_measure) && File.file?(path_to_measure)
          path_to_measure = File.dirname(path_to_measure)
        end

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

        # do not allow the choice variable_type

        s.type = hash[:measure_type] # this is actually the measure type
        if hash[:arguments]
          hash[:arguments].each do |arg|
            var_type = arg[:variable_type].downcase
            if var_type == 'choice'
              # WARN the user that the measure had a "choice data type"
              var_type = 'string'
            end

            s.arguments << {
                display_name: arg[:display_name],
                display_name_short: arg[:display_name],
                name: arg[:local_variable],
                value_type: var_type,
                default_value: arg[:default_value],
                value: arg[:default_value]
            }
          end
        end

        s
      end

      private

      # validate the arguments of the distribution
      def distribution_valid?(d)
        # regardless of uncertainty description the following must be defined
        fail "No distribution defined for variable" unless d[:type]
        fail "No minimum defined for variable" unless d[:minimum]
        fail "No maximum defined for variable" unless d[:maximum]
        fail "No mean/mode defined for variable" unless d[:mode]

        if d[:type] =~ /discrete/
          # require min, max, mode
          fail "No values passed for discrete distribution" unless d[:values] || d[:values].empty?
          if d[:weights]
            fail "Weights are not the same length as values" unless d[:values].size == d[:weights].size
            fail "Weights do not sum up to one" unless d[:weights].reduce(:+) == 1
          else
            fraction = 1 / d[:values].size.to_f
            d[:weights] = [fraction] * d[:values.size]
          end
        elsif d[:type] =~ /triangle/
          # requires min, max, mode

        elsif d[:type] =~ /normal/ # both normal and lognormal
          # require min, max, mode, stddev
          fail "No standard deviation for variable" unless d[:standard_deviation]
        end


        true
      end

    end
  end
end
