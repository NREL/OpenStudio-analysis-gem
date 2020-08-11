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

module OpenStudio
  module Analysis
    module Translator
      class Workflow
        attr_reader :osa_filename
        attr_reader :root_path
        attr_reader :analysis
        attr_reader :osa
        attr_reader :osw_version
        attr_reader :options
        attr_reader :file_paths
        attr_reader :measure_paths
        attr_reader :seed_file
        attr_reader :weather_file
        attr_reader :osa_id
        attr_reader :steps

        def initialize(osa_filename, options = {})
          @osa_filename = osa_filename
          @root_path = File.expand_path(File.dirname(@osa_filename))

          # try to read the osa json file
          if File.exist?(@osa_filename)
            @osa = ::JSON.parse(File.read(@osa_filename), symbolize_names: true)[:analysis]
          else
            raise "File #{@osa_filename} does not exist"
          end

          # Initialize some other instance variables
          @osw_version = '0.0.1'
          @options = options
          @file_paths = options[:file_paths] ? options[:file_paths] : []
          @file_paths << '../../lib'
          @measure_paths = options[:measure_paths] ? options[:measure_paths] : []

          # Initialize static inputs from the OSA
          @seed_file = File.basename(@osa[:seed][:path])
          if @options[:seed]
            @seed_file = @options[:seed]
          end
          @weather_file = File.basename(@osa[:weather_file][:path])
          @osa_id = @osa[:_id]
          @steps = []
          @osa[:problem][:workflow].each_with_index do |step, i|
            step_hash = {}
            step_hash[:measure_dir_name] = File.basename(step[:measure_definition_directory])
            step_hash[:arguments] = {}
            # Measures can have no arguments -- make sure to catch it
            @osa[:problem][:workflow][i][:arguments]&.each do |arg|
              next if arg[:value].nil?
              step_hash[:arguments][arg[:name].to_sym] = arg[:value]
            end
            step_hash[:name] = step[:name] if step[:name]
            step_hash[:description] = step[:description] if step[:description]
            if @options[:da_descriptions]
              step_hash[:name] = @options[:da_descriptions][i][:name]
              step_hash[:description] = @options[:da_descriptions][i][:description]
            end
            # DLM: the following fields are deprecated and should be removed once EDAPT reports no longer rely on them, they are moved to step.results
            step_hash[:measure_id] = step[:measure_definition_uuid] if step[:measure_definition_uuid]
            step_hash[:version_id] = step[:measure_definition_version_uuid] if step[:measure_definition_version_uuid]
            step_hash[:modeler_description] = step[:modeler_description] if step[:modeler_description]
            step_hash[:taxonomy] = step[:taxonomy] if step[:taxonomy]
            step_hash[:measure_type] = step[:measure_type]
            step_hash[:measure_type] = 'ModelMeasure'
            @steps << step_hash
          end
        end

        # Convert a file in the form of an OSD into an OSW
        def process_datapoint(osd_filename)
          # Try to read the osd json file
          osd = nil
          if File.exist?(osd_filename)
            osd = ::JSON.parse(File.read(osd_filename), symbolize_names: true)[:data_point]
          else
            raise "File #{osd_filename} does not exist"
          end

          # Parse the osd hash based off of the osa hash. First check that the analysis id matches
          raise "File #{osd_filename} does not reference #{@osa_id}." unless @osa_id == osd[:analysis_id]
          osw_steps_instance = @steps
          osw_steps_instance.each_with_index do |step, i|
            next unless @osa[:problem][:workflow][i][:variables]
            @osa[:problem][:workflow][i][:variables].each do |var|
              var_name = var[:argument][:name]
              var_value_uuid = var[:uuid]
              var_value = osd[:set_variable_values][var_value_uuid.to_sym]
              step[:arguments][var_name.to_sym] = var_value
            end
          end

          # Overwrite the seed and weather files if they are present in the datapoint.json
          if (osd[:weather_file] != '') && !osd[:weather_file].nil?
            weather_file = osd[:weather_file]
          else
            weather_file = @weather_file
          end
          if (osd[:seed] != '') && !osd[:seed].nil?
            seed_file = osd[:seed]
          else
            seed_file = @seed_file
          end

          # Save the OSW hash
          osw = {}
          created_at = ::Time.now
          osw[:seed_file] = seed_file
          osw[:weather_file] = weather_file
          osw[:file_format_version] = @osw_version
          osw[:osa_id] = @osa_id
          osw[:osd_id] = osd[:_id]
          osw[:created_at] = created_at
          osw[:measure_paths] = @measure_paths
          osw[:file_paths] = @file_paths
          osw[:run_directory] = './run'
          osw[:steps] = osw_steps_instance
          osw[:name] = osd[:name] if osd[:name]
          osw[:description] = osd[:description] if osd[:description]
          osw
        end

        # Runs an array of OSD files
        def process_datapoints(osd_filename_array)
          r = []
          osd_filename_array.each do |osd_file|
            r << process_datapoint(osd_file)
          rescue StandardError => e
            r << nil
            puts "Warning: Failed to process datapoint #{osd_file} with error #{e.message} in #{e.backtrace.join('\n')}"
          end

          r
        end
      end
    end
  end
end
