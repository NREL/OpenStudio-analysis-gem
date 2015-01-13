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
      attr_accessor :measure_definition_directory_local
      attr_accessor :measure_definition_display_name
      attr_accessor :measure_definition_name
      attr_accessor :measure_definition_name_xml
      attr_accessor :measure_definition_uuid
      attr_accessor :measure_definition_version_uuid
      attr_reader :arguments
      attr_reader :variables

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
        @measure_definition_directory_local = nil
        @measure_definition_display_name = nil
        @measure_definition_name = nil
        @measure_definition_name_xml = nil
        @measure_definition_uuid = nil
        @measure_definition_version_uuid = nil
        @arguments = []

        # TODO: eventually the variables should be its own class. This would then be an array of Variable objects.
        @variables = []
      end

      # Return an array of the argument names
      #
      # @return [Array] Listing of argument names.
      def argument_names
        @arguments.map { |a| a[:name] }
      end

      # Set the value of an argument to `value`. The user is required to know the data type and pass it in accordingly
      #
      # @param argument_name [String] The machine name of the argument that you want to set the value to
      # @param value [] The value to assign the argument
      # @return [Boolean] True/false if it assigned it
      def argument_value(argument_name, value)
        a = @arguments.find_all { |a| a[:name] == argument_name }
        fail "could not find argument_name of #{argument_name} in measure #{name}. Valid argument names are #{argument_names}." if a.empty?
        fail "more than one argument with the same name of #{argument_name} in measure #{name}" if a.size > 1

        a = a.first

        a[:value] = value

        a[:value] == value
      end
      # Tag a measure's argument as a variable.
      #
      # @param argument_name [String] The instance_name of the measure argument that is to be tagged. This is the same name as the argument's variable in the measure.rb file.
      # @param variable_display_name [String] What the variable is called. It is best if the display name is self describing (i.e. does not need any other context). It can be the same as the argument display name.
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
      # @option options [String] :static_value Static/Default value of the variable. If not defined it will use the default value for the argument. This can be set later as well using the `argument_value` method.
      # @return [Boolean] True / False if it was able to tag the measure argument
      def make_variable(argument_name, variable_display_name, distribution, options = {})
        options = { variable_type: 'variable' }.merge(options)
        distribution[:mode] = distribution[:mean] if distribution.key? :mean

        a = @arguments.find_all { |a| a[:name] == argument_name }
        fail "could not find argument_name of #{argument_name} in measure #{name}. Valid argument names are #{argument_names}." if a.empty?
        fail "more than one argument with the same name of #{argument_name} in measure #{name}" if a.size > 1

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
          # TODO: Static value should be named default value or just value

          if distribution[:type] =~ /discrete/
            v[:weights] = distribution[:weights]
            v[:values] = distribution[:values]
          elsif distribution[:type] =~ /uniform/
            # all the data should be present
          elsif distribution[:type] =~ /triangle/
            v[:step_size] = distribution[:step_size] ? distribution[:step_size] : nil
            # stddev is not saves when triangular
          elsif distribution[:type] =~ /normal/
            v[:step_size] = distribution[:step_size] ? distribution[:step_size] : nil
            v[:standard_deviation] = distribution[:standard_deviation]
          end

          # assign uuid and version id to the variable
          v[:uuid] = SecureRandom.uuid
          v[:version_uuid] = SecureRandom.uuid
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
          instance_variables.each do |var|
            if var.to_s == '@type'
              hash[:measure_type] = instance_variable_get(var)
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
            elsif var.to_s == '@__swigtype__'
              # skip the swig variables caused by using the same namespace as OpenStudio
            else
              hash[var.to_s.delete('@')] = instance_variable_get(var)
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
            warn 'Deprecation Warning. RubyContinuousVariable (OpenStudio called this the variable_type) is no longer persisted'

            # This is not neatly coded. This should be a new object that knows how to write itself out.
            v[:uncertainty_description][:attributes] = []
            if v[:type] =~ /discrete/
              new_h = {}
              new_h[:name] = 'discrete'
              new_h[:values_and_weights] = v.delete(:values).zip(v.delete(:weights)).map { |w| { value: w[0], weight: w[1] } }
              v[:uncertainty_description][:attributes] << new_h

              v[:uncertainty_description][:attributes] << { name: 'lower_bounds', value: v[:minimum] }
              v[:uncertainty_description][:attributes] << { name: 'upper_bounds', value: v[:maximum] }
              v[:uncertainty_description][:attributes] << { name: 'modes', value: v[:mode] }
            elsif v[:type] =~ /uniform/
              v[:uncertainty_description][:attributes] << { name: 'lower_bounds', value: v[:minimum] }
              v[:uncertainty_description][:attributes] << { name: 'upper_bounds', value: v[:maximum] }
              v[:uncertainty_description][:attributes] << { name: 'modes', value: v[:mode] }
            else
              v[:uncertainty_description][:attributes] << { name: 'lower_bounds', value: v[:minimum] }
              v[:uncertainty_description][:attributes] << { name: 'upper_bounds', value: v[:maximum] }
              v[:uncertainty_description][:attributes] << { name: 'modes', value: v[:mode] }
              v[:uncertainty_description][:attributes] << { name: 'delta_x', value: v[:step_size] ? v[:step_size] : nil }
              v[:uncertainty_description][:attributes] << { name: 'stddev', value: v[:standard_deviation] ? v[:standard_deviation] : nil }
            end

            v[:workflow_index] = index
            warn 'Deprecation Warning. workflow_step_type is no longer persisted'

            # remove some remaining items
            v.delete(:type)
            v.delete(:mode) if v.key?(:mode)
            v.delete(:step_size) if v.key?(:step_size)
            v.delete(:standard_deviation) if v.key?(:standard_deviation)
          end

        else
          fail "Do not know how to create the Hash for Version #{version}"
        end

        hash
      end

      # Read the workflow item from a measure hash.
      #
      # @param instance_name [String] Machine name of the instance
      # @param instance_display_name [String] Display name of the instance
      # @param path_to_measure [String] This is the local path to the measure directroy, relative or absolute. It is used when zipping up all the measures.
      # @param hash [Hash] Measure hash in the format of the measure.json (from the Analysis Spreadsheet project)

      # @return [Object] Returns the OpenStudio::Analysis::WorkflowStep
      def self.from_measure_hash(instance_name, instance_display_name, path_to_measure, hash)
        # TODO: Validate the hash
        # TODO: validate that the measure exists?

        # verify that the path to the measure is a path and not a file. If it is make it a path
        if File.exist?(path_to_measure) && File.file?(path_to_measure)
          path_to_measure = File.dirname(path_to_measure)
        end

        # Extract the directo
        path_to_measure_local = path_to_measure
        path_to_measure = "./measures/#{File.basename(path_to_measure)}"

        # map the BCL hash format into the OpenStudio WorkflowStep format
        s = OpenStudio::Analysis::WorkflowStep.new

        # add the instance and display name
        s.name = instance_name
        s.display_name = instance_display_name

        # definition of the measure
        s.measure_definition_class_name = hash[:classname]
        s.measure_definition_directory = path_to_measure
        s.measure_definition_directory_local = path_to_measure_local
        s.measure_definition_display_name = hash[:display_name]
        s.measure_definition_name = hash[:name]
        # name_xml is not used right now but eventually should be used to compare the hash[:name] and the hash[:name_xml]
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
              name: arg[:name],
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
        fail 'No distribution defined for variable' unless d.key? :type
        fail 'No minimum defined for variable' unless d.key? :minimum
        fail 'No maximum defined for variable' unless d.key? :maximum
        fail 'No mean/mode defined for variable' unless d.key? :mode

        if d[:type] =~ /uniform/
          # Do we need to tell the user that we don't really need the mean/mode for uniform?
        elsif d[:type] =~ /discrete/
          # require min, max, mode
          fail 'No values passed for discrete distribution' unless d[:values] || d[:values].empty?
          if d[:weights]
            fail 'Weights are not the same length as values' unless d[:values].size == d[:weights].size
            fail 'Weights do not sum up to one' unless d[:weights].reduce(:+).between?(0.99, 1.01) # allow a small error for now
          else
            fraction = 1 / d[:values].size.to_f
            d[:weights] = [fraction] * d[:values].size
          end
        elsif d[:type] =~ /triangle/
          # requires min, max, mode

        elsif d[:type] =~ /normal/ # both normal and lognormal
          # require min, max, mode, stddev
          fail 'No standard deviation for variable' unless d[:standard_deviation]
        end

        true
      end
    end
  end
end
