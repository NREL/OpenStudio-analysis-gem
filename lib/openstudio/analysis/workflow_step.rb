# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

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

        @arguments << {
          display_name: 'Skip Entire Measure',
          display_name_short: 'Skip',
          name: '__SKIP__',
          value_type: 'boolean',
          default_value: false,
          value: false
        }

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
        raise "could not find argument_name of #{argument_name} in measure #{name}. Valid argument names are #{argument_names}." if a.empty?
        raise "more than one argument with the same name of #{argument_name} in measure #{name}" if a.size > 1

        a = a.first

        a[:value] = value

        a[:value] == value
      end

      # Return a variable by its name.
      #
      # @param name [String] Name of the arugment that makes the variable.
      # @return [Object] The variable object
      def find_variable_by_name(name)
        v = @variables.find { |v| v[:argument][:name] == name }

        v
      end

      # Tag a measure's argument as a variable.
      #
      # @param argument_name [String] The instance_name of the measure argument that is to be tagged. This is the same name as the argument's variable in the measure.rb file.
      # @param variable_display_name [String] What the variable is called. It is best if the display name is self describing (i.e. does not need any other context). It can be the same as the argument display name.
      # @param distribution [Hash] Hash describing the distribution of the variable.
      # @option distribution [String] :type Type of distribution. `discrete`, `uniform`, `triangle`, `normal`, `lognormal`, `integer_sequence`
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
      # @return [Boolean] True / False if it was able to tag the measure argument
      def make_variable(argument_name, variable_display_name, distribution, options = {})
        options = { variable_type: 'variable' }.merge(options)
        distribution[:mode] = distribution[:mean] if distribution.key? :mean

        raise "Set the static value in the options 'options[:static_value]', not the distribution" if distribution[:static_value]

        a = @arguments.find_all { |a| a[:name] == argument_name }
        raise "could not find argument_name of #{argument_name} in measure #{name}. Valid argument names are #{argument_names}." if a.empty?
        raise "more than one argument with the same name of #{argument_name} in measure #{name}" if a.size > 1

        if distribution_valid?(distribution)
          # grab the argument hash
          a = a.first

          # add more information to the argument
          v = {}
          v[:argument] = a
          v[:display_name] = variable_display_name
          v[:display_name_short] = options[:variable_display_name_short] ? options[:variable_display_name_short] : variable_display_name
          v[:variable_type] = options[:variable_type]

          v[:type] = distribution[:type]
          v[:units] = distribution[:units] ? distribution[:units] : nil
          v[:minimum] = distribution[:minimum]
          v[:maximum] = distribution[:maximum]
          v[:relation_to_output] = distribution[:relation_to_output] ? distribution[:relation_to_output] : nil
          v[:mode] = distribution[:mode]
          v[:static_value] = options[:static_value] if options[:static_value]
          # TODO: Static value should be named default value or just value

          # Always look for these attributes even if the distribution does not need them
          v[:weights] = distribution[:weights] if distribution[:weights]
          v[:values] = distribution[:values] if distribution[:values]
          v[:standard_deviation] = distribution[:standard_deviation] if distribution[:standard_deviation]
          v[:step_size] = distribution[:step_size] ? distribution[:step_size] : nil

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

            # TODO: iterate over the variables and create UUIDs, or not?
          end

          # fix everything to support the legacy version
          hash[:variables] = @variables

          # Clean up the variables to match the legacy format
          hash[:variables].each_with_index do |v, index|
            v[:variable_type] == 'pivot' ? v[:pivot] = true : v[:variable] = true
            v[:static_value] = v[:argument][:default_value] unless v[:static_value]

            v[:uncertainty_description] = {}
            # In Version 0.5 the _uncertain text will be removed from distribution
            if v[:type] =~ /uncertain/
              v[:type].delete!('_uncertain')
            end
            v[:uncertainty_description][:type] = v[:type]

            # This is not neatly coded. This should be a new object that knows how to write itself out.
            v[:uncertainty_description][:attributes] = []
            if v[:type] =~ /discrete/
              new_h = {}
              new_h[:name] = 'discrete'

              # check the weights
              new_h[:values_and_weights] = v.delete(:values).zip(v.delete(:weights)).map { |w| { value: w[0], weight: w[1] } }
              v[:uncertainty_description][:attributes] << new_h
            end

            # always write out these attributes
            v[:uncertainty_description][:attributes] << { name: 'lower_bounds', value: v[:minimum] }
            v[:uncertainty_description][:attributes] << { name: 'upper_bounds', value: v[:maximum] }
            v[:uncertainty_description][:attributes] << { name: 'modes', value: v[:mode] }
            v[:uncertainty_description][:attributes] << { name: 'delta_x', value: v[:step_size] ? v[:step_size] : nil }
            v[:uncertainty_description][:attributes] << { name: 'stddev', value: v[:standard_deviation] ? v[:standard_deviation] : nil }

            v[:workflow_index] = index

            # remove some remaining items
            v.delete(:type)
            v.delete(:mode) if v.key?(:mode)
            v.delete(:step_size) if v.key?(:step_size)
            v.delete(:standard_deviation) if v.key?(:standard_deviation)
          end

        else
          raise "Do not know how to create the Hash for Version #{version}"
        end

        hash
      end

      # Read the workflow item from a measure hash.
      #
      # @param instance_name [String] Machine name of the instance
      # @param instance_display_name [String] Display name of the instance
      # @param path_to_measure [String] This is the local path to the measure directroy, relative or absolute. It is used when zipping up all the measures.
      # @param hash [Hash] Measure hash in the format of the measure.json (from the Analysis Spreadsheet project)
      # @param options [Hash] Optional arguments
      # @option options [Boolean] :ignore_not_found Do not raise an exception if the measure could not be found on the machine
      # @return [Object] Returns the OpenStudio::Analysis::WorkflowStep
      def self.from_measure_hash(instance_name, instance_display_name, path_to_measure, hash, options = {})
        # TODO: Validate the hash
        # TODO: validate that the measure exists?

        if File.directory? path_to_measure
          path_to_measure = File.join(path_to_measure, 'measure.rb')
        end

        # verify that the path to the measure is a path and not a file. If it is make it a path
        if File.exist?(path_to_measure) && File.file?(path_to_measure)
          path_to_measure = File.dirname(path_to_measure)
        else
          raise "Could not find measure '#{instance_name}' in '#{path_to_measure}'" unless options[:ignore_not_found]
        end

        # Extract the directory
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
        hash[:arguments]&.each do |arg|
          # warn the user to we need to deprecate variable_type and use value_type (which is what os server uses)
          var_type = arg[:variable_type] ? arg[:variable_type].downcase : arg[:value_type]

          if var_type == 'choice'
            # WARN the user that the measure had a "choice data type"
            var_type = 'string'
          end

          s.arguments << {
            display_name: arg[:display_name],
            display_name_short: arg[:display_name_short],
            name: arg[:name],
            value_type: var_type,
            default_value: arg[:default_value],
            value: arg[:default_value]
          }
        end

        # Load the arguments of variables, but do not make them variables. This format is more about arugments, than variables
        hash[:variables]&.each do |variable|
          # add the arguments first
          s.arguments << {
            display_name: variable[:argument][:display_name],
            display_name_short: variable[:argument][:display_name_short],
            name: variable[:argument][:name],
            value_type: variable[:argument][:value_type],
            default_value: variable[:argument][:default_value],
            value: variable[:argument][:default_value]
          }
        end

        s
      end

      # Read the workflow item from a analysis hash. Can we combine measure hash and analysis hash?
      #
      # @param instance_name [String] Machine name of the instance
      # @param instance_display_name [String] Display name of the instance
      # @param path_to_measure [String] This is the local path to the measure directroy, relative or absolute. It is used when zipping up all the measures.
      # @param hash [Hash] Measure hash in the format of the measure.json (from the Analysis Spreadsheet project)
      # @param options [Hash] Optional arguments
      # @option options [Boolean] :ignore_not_found Do not raise an exception if the measure could not be found on the machine
      # @return [Object] Returns the OpenStudio::Analysis::WorkflowStep
      def self.from_analysis_hash(instance_name, instance_display_name, path_to_measure, hash, options = {})
        # TODO: Validate the hash
        # TODO: validate that the measure exists?

        if File.directory? path_to_measure
          path_to_measure = File.join(path_to_measure, 'measure.rb')
        end

        # verify that the path to the measure is a path and not a file. If it is make it a path
        if File.exist?(path_to_measure) && File.file?(path_to_measure)
          path_to_measure = File.dirname(path_to_measure)
        else
          raise "Could not find measure '#{instance_name}' in '#{path_to_measure}'" unless options[:ignore_not_found]
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
        s.measure_definition_class_name = hash[:measure_definition_class_name]
        s.measure_definition_directory = path_to_measure
        s.measure_definition_directory_local = path_to_measure_local
        s.measure_definition_display_name = hash[:measure_definition_display_name]
        s.measure_definition_name = hash[:measure_definition_name]
        # name_xml is not used right now but eventually should be used to compare the hash[:name] and the hash[:name_xml]
        s.measure_definition_name_xml = hash[:measure_definition_name_xml]
        s.measure_definition_uuid = hash[:measure_definition_uuid]
        s.measure_definition_version_uuid = hash[:measure_definition_version_uuid]

        s.type = hash[:measure_type] # this is actually the measure type
        hash[:arguments]&.each do |arg|
          # warn the user to we need to deprecate variable_type and use value_type (which is what os server uses)
          var_type = arg[:value_type]

          if var_type == 'choice'
            # WARN the user that the measure had a "choice data type"
            var_type = 'string'
          end

          s.arguments << {
            display_name: arg[:display_name],
            display_name_short: arg[:display_name_short],
            name: arg[:name],
            value_type: var_type,
            default_value: arg[:default_value],
            value: arg[:value]
          }
        end

        hash[:variables]&.each do |variable|
          # add the arguments first
          s.arguments << {
            display_name: variable[:argument][:display_name],
            display_name_short: variable[:argument][:display_name_short],
            name: variable[:argument][:name],
            value_type: variable[:argument][:value_type],
            default_value: variable[:argument][:default_value],
            value: variable[:argument][:default_value]
          }

          var_options = {}
          var_options[:variable_type] = variable[:variable_type]
          var_options[:variable_display_name_short] = variable[:display_name_short]
          var_options[:static_value] = variable[:static_value]
          distribution = variable[:uncertainty_description]
          distribution[:minimum] = variable[:minimum]
          distribution[:mean] = distribution[:attributes].find { |a| a[:name] == 'modes' }[:value]
          distribution[:maximum] = variable[:maximum]
          distribution[:standard_deviation] = distribution[:attributes].find { |a| a[:name] == 'stddev' }[:value]
          distribution[:step_size] = distribution[:attributes].find { |a| a[:name] == 'delta_x' }[:value]
          s.make_variable(variable[:argument][:name], variable[:display_name], distribution, var_options)
        end

        s
      end

      private

      # validate the arguments of the distribution
      def distribution_valid?(d)
        # regardless of uncertainty description the following must be defined
        raise 'No distribution defined for variable' unless d.key? :type
        raise 'No minimum defined for variable' unless d.key? :minimum
        raise 'No maximum defined for variable' unless d.key? :maximum
        raise 'No mean/mode defined for variable' unless d.key? :mode

        if d[:type] =~ /uniform/
          # Do we need to tell the user that we don't really need the mean/mode for uniform ?
        elsif d[:type] =~ /discrete/
          # require min, max, mode
          raise 'No values passed for discrete distribution' unless d[:values] || d[:values].empty?
          if d[:weights]
            raise 'Weights are not the same length as values' unless d[:values].size == d[:weights].size
            raise 'Weights do not sum up to one' unless d[:weights].reduce(:+).between?(0.99, 1.01) # allow a small error for now
          else
            fraction = 1 / d[:values].size.to_f
            d[:weights] = [fraction] * d[:values].size
          end
        elsif d[:type] =~ /integer_sequence/
          d[:weights] = 1
          d[:values] = 1
        elsif d[:type] =~ /triangle/
          # requires min, max, mode
        elsif d[:type] =~ /normal/ # both normal and lognormal
          # require min, max, mode, stddev
          raise 'No standard deviation for variable' unless d[:standard_deviation]
        end

        true
      end
    end
  end
end
