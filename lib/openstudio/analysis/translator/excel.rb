# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2023, Alliance for Sustainable Energy, LLC.
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
      class Excel
        attr_reader :version
        attr_reader :settings
        attr_reader :variables
        attr_reader :outputs
        attr_reader :models
        attr_reader :weather_files
        attr_reader :measure_paths
        attr_reader :weather_paths
        attr_reader :worker_inits
        attr_reader :worker_finals
        attr_reader :export_path
        attr_reader :cluster_name
        attr_reader :variables
        attr_reader :algorithm
        attr_reader :problem
        attr_reader :run_setup
        attr_reader :aws_tags

        # remove these once we have classes to construct the JSON file
        attr_accessor :name
        attr_accessor :cluster_name
        attr_reader :analysis_name

        # methods to override instance variables

        # pass in the filename to read
        def initialize(xls_filename)
          @xls_filename = xls_filename
          @root_path = File.expand_path(File.dirname(@xls_filename))

          @xls = nil
          # try to read the spreadsheet as a roo object
          if File.exist?(@xls_filename)
            @xls = Roo::Spreadsheet.open(@xls_filename)
          else
            raise "File #{@xls_filename} does not exist"
          end

          # Initialize some other instance variables
          @version = '0.0.1'
          @analyses = [] # Array o OpenStudio::Analysis. Use method to access
          @name = nil
          @analysis_name = nil
          @settings = {}
          @weather_files = []
          @weather_paths = []
          @models = []
          @other_files = []
          @worker_inits = []
          @worker_finals = []
          @export_path = './export'
          @measure_paths = []
          @number_of_samples = 0 # TODO: remove this
          @problem = {}
          @algorithm = {}
          @outputs = {}
          @run_setup = {}
          @aws_tags = []
        end

        def process
          @setup = parse_setup

          @version = Semantic::Version.new @version
          raise "Spreadsheet version #{@version} is no longer supported.  Please upgrade your spreadsheet to at least 0.1.9" if @version < '0.1.9'

          @variables = parse_variables

          @outputs = parse_outputs

          # call validate to make sure everything that is needed exists (i.e. directories)
          validate_analysis
        end

        # Helper methods to remove models and add new ones programatically. Note that these should
        # be moved into a general analysis class
        def delete_models
          @models = []
        end

        def add_model(name, display_name, type, path)
          @models << {
            name: name,
            display_name: display_name,
            type: type,
            path: path
          }
        end

        def validate_analysis
          # Setup the paths and do some error checking
          @measure_paths.each do |mp|
            raise "Measures directory '#{mp}' does not exist" unless Dir.exist?(mp)
          end

          @models.uniq!
          raise 'No seed models defined in spreadsheet' if @models.empty?

          @models.each do |model|
            raise "Seed model does not exist: #{model[:path]}" unless File.exist?(model[:path])
          end

          @weather_files.uniq!
          raise 'No weather files found based on what is in the spreadsheet' if @weather_files.empty?

          @weather_files.each do |wf|
            raise "Weather file does not exist: #{wf}" unless File.exist?(wf)
          end

          # This can be a directory as well
          @other_files.each do |f|
            raise "Other files do not exist for: #{f[:path]}" unless File.exist?(f[:path])
          end

          @worker_inits.each do |f|
            raise "Worker initialization file does not exist for: #{f[:path]}" unless File.exist?(f[:path])
          end

          @worker_finals.each do |f|
            raise "Worker finalization file does not exist for: #{f[:path]}" unless File.exist?(f[:path])
          end

          FileUtils.mkdir_p(@export_path)

          # verify that the measure display names are unique
          # puts @variables.inspect
          measure_display_names = @variables['data'].map { |m| m['enabled'] ? m['display_name'] : nil }.compact
          measure_display_names_mult = measure_display_names.select { |m| measure_display_names.count(m) > 1 }.uniq
          if measure_display_names_mult && !measure_display_names_mult.empty?
            raise "Measure Display Names are not unique for '#{measure_display_names_mult.join('\', \'')}'"
          end

          # verify that all continuous variables have all the data needed and create a name map
          variable_names = []
          @variables['data'].each do |measure|
            if measure['enabled']
              measure['variables'].each do |variable|
                # Determine if row is suppose to be an argument or a variable to be perturbed.
                if variable['variable_type'] == 'variable'
                  variable_names << variable['display_name']

                  # make sure that variables have static values
                  if variable['distribution']['static_value'].nil? || variable['distribution']['static_value'] == ''
                    raise "Variable #{measure['name']}:#{variable['name']} needs a static value"
                  end

                  if variable['type'] == 'enum' || variable['type'] == 'Choice'
                    # check something
                  else # must be an integer or double
                    if variable['distribution']['type'] == 'discrete_uncertain'
                      if variable['distribution']['discrete_values'].nil? || variable['distribution']['discrete_values'] == ''
                        raise "Variable #{measure['name']}:#{variable['name']} needs discrete values"
                      end
                    elsif variable['distribution']['type'] == 'integer_sequence'
                      if variable['distribution']['mean'].nil? || variable['distribution']['mean'] == ''
                        raise "Variable #{measure['name']}:#{variable['name']} must have a mean/mode"
                      end
                      if variable['distribution']['min'].nil? || variable['distribution']['min'] == ''
                        raise "Variable #{measure['name']}:#{variable['name']} must have a minimum"
                      end
                      if variable['distribution']['max'].nil? || variable['distribution']['max'] == ''
                        raise "Variable #{measure['name']}:#{variable['name']} must have a maximum"
                      end
                    else
                      if variable['distribution']['mean'].nil? || variable['distribution']['mean'] == ''
                        raise "Variable #{measure['name']}:#{variable['name']} must have a mean"
                      end
                      if variable['distribution']['stddev'].nil? || variable['distribution']['stddev'] == ''
                        raise "Variable #{measure['name']}:#{variable['name']} must have a stddev"
                      end
                    end

                    if variable['distribution']['mean'].nil? || variable['distribution']['mean'] == ''
                      raise "Variable #{measure['name']}:#{variable['name']} must have a mean/mode"
                    end
                    if variable['distribution']['min'].nil? || variable['distribution']['min'] == ''
                      raise "Variable #{measure['name']}:#{variable['name']} must have a minimum"
                    end
                    if variable['distribution']['max'].nil? || variable['distribution']['max'] == ''
                      raise "Variable #{measure['name']}:#{variable['name']} must have a maximum"
                    end
                    unless variable['type'] == 'string' || variable['type'] =~ /bool/
                      if variable['distribution']['min'] > variable['distribution']['max']
                        raise "Variable min is greater than variable max for #{measure['name']}:#{variable['name']}"
                      end
                    end

                  end
                end
              end
            end
          end

          dupes = variable_names.select { |e| variable_names.count(e) > 1 }.uniq
          if dupes.count > 0
            raise "duplicate variable names found in list #{dupes.inspect}"
          end

          # most of the checks will raise a runtime exception, so this true will never be called
          true
        end

        # convert the data in excel's parsed data into an OpenStudio Analysis Object
        #
        # @seed_model [Hash] Seed model to set the new analysis to
        # @append_model_name [Boolean] Append the name of the seed model to the display name
        # @return [Object] An OpenStudio::Analysis
        def analysis(seed_model = nil, append_model_name = false)
          raise 'There are no seed models defined in the excel file. Please add one.' if @models.empty?
          raise "There are more than one seed models defined in the excel file. Call 'analyses' to return the array" if @models.size > 1 && seed_model.nil?

          seed_model = @models.first if seed_model.nil?

          # Use the programmatic interface to make the analysis
          # append the model name to the analysis name if requested (normally if there are more than 1 models in the spreadsheet)
          display_name = append_model_name ? @name + ' ' + seed_model[:display_name] : @name

          a = OpenStudio::Analysis.create(display_name)

          @variables['data'].each do |measure|
            next unless measure['enabled']

            @measure_paths.each do |measure_path|
              measure_dir_to_add = "#{measure_path}/#{measure['measure_file_name_directory']}"
              if Dir.exist? measure_dir_to_add
                if File.exist? "#{measure_dir_to_add}/measure.rb"
                  measure['local_path_to_measure'] = "#{measure_dir_to_add}/measure.rb"
                  break
                else
                  raise "Measure in directory '#{measure_dir_to_add}' did not contain a measure.rb file"
                end
              end
            end

            raise "Could not find measure '#{measure['name']}' in directory named '#{measure['measure_file_name_directory']}' in the measure paths '#{@measure_paths.join(', ')}'" unless measure['local_path_to_measure']

            a.workflow.add_measure_from_excel(measure)
          end

          @other_files.each do |library|
            a.libraries.add(library[:path], library_name: library[:lib_zip_name])
          end

          @worker_inits.each do |w|
            a.worker_inits.add(w[:path], args: w[:args])
          end

          @worker_finals.each do |w|
            a.worker_finalizes.add(w[:path], args: w[:args])
          end

          # Add in the outputs
          @outputs['output_variables'].each do |o|
            o = Hash[o.map { |k, v| [k.to_sym, v] }]
            a.add_output(o)
          end

          a.analysis_type = @problem['analysis_type']
          @algorithm.each do |k, v|
            a.algorithm.set_attribute(k, v)
          end

          # clear out the seed files before adding new ones
          a.seed_model = seed_model[:path]

          # clear out the weather files before adding new ones
          a.weather_files.clear
          @weather_paths.each do |wp|
            a.weather_files.add_files(wp)
          end

          a
        end

        # Return an array of analyses objects of OpenStudio::Analysis::Formulation
        def analyses
          as = []
          @models.map do |model|
            as << analysis(model, @models.count > 1)
          end

          as
        end

        # Method to return the cluster name for backwards compatibility
        def cluster_name
          @settings['cluster_name']
        end

        # save_analysis will iterate over each model that is defined in the spreadsheet and save the
        # zip and json file.
        def save_analysis
          analyses.each do |a|
            puts "Saving JSON and ZIP file for #{@name}:#{a.display_name}"
            json_file_name = "#{@export_path}/#{a.name}.json"
            FileUtils.rm_f(json_file_name) if File.exist?(json_file_name)
            # File.open(json_file_name, 'w') { |f| f << JSON.pretty_generate(new_analysis_json) }

            a.save json_file_name
            a.save_zip "#{File.dirname(json_file_name)}/#{File.basename(json_file_name, '.*')}.zip"
          end
        end

        protected

        # parse_setup will pull out the data on the "setup" tab and store it in memory for later use
        def parse_setup
          rows = @xls.sheet('Setup').parse
          b_settings = false
          b_run_setup = false
          b_problem_setup = false
          b_algorithm_setup = false
          b_weather_files = false
          b_models = false
          b_other_libs = false
          b_worker_init = false
          b_worker_final = false

          rows.each do |row|
            if row[0] == 'Settings'
              b_settings = true
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              b_worker_init = false
              b_worker_final = false
              next
            elsif row[0] == 'Running Setup'
              b_settings = false
              b_run_setup = true
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              b_worker_init = false
              b_worker_final = false
              next
            elsif row[0] == 'Problem Definition'
              b_settings = false
              b_run_setup = false
              b_problem_setup = true
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              b_worker_init = false
              b_worker_final = false
              next
            elsif row[0] == 'Algorithm Setup'
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = true
              b_weather_files = false
              b_models = false
              b_other_libs = false
              b_worker_init = false
              b_worker_final = false
              next
            elsif row[0] == 'Weather Files'
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = true
              b_models = false
              b_other_libs = false
              b_worker_init = false
              b_worker_final = false
              next
            elsif row[0] == 'Models'
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = true
              b_other_libs = false
              b_worker_init = false
              b_worker_final = false
              next
            elsif row[0] == 'Other Library Files'
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = true
              b_worker_init = false
              b_worker_final = false
              next
            elsif row[0] =~ /Worker Initialization Scripts/
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              b_worker_init = true
              b_worker_final = false
              next
            elsif row[0] =~ /Worker Finalization Scripts/
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              b_worker_init = false
              b_worker_final = true
              next
            end

            next if row[0].nil?

            if b_settings
              @version = row[1].chomp if row[0] == 'Spreadsheet Version'
              @settings[row[0].to_underscore.to_s] = row[1] if row[0]
              if @settings['cluster_name']
                @settings['cluster_name'] = @settings['cluster_name'].to_underscore
              end

              if row[0] == 'AWS Tag'
                @aws_tags << row[1].strip
              end

              # type some of the values that we know
              @settings['proxy_port'] = @settings['proxy_port'].to_i if @settings['proxy_port']

            elsif b_run_setup
              if row[0] == 'Analysis Name'
                if row[1]
                  @name = row[1]
                else
                  @name = SecureRandom.uuid
                end
                @analysis_name = @name.to_underscore
              end
              if row[0] == 'Export Directory'
                tmp_filepath = row[1]
                if (Pathname.new tmp_filepath).absolute?
                  @export_path = tmp_filepath
                else
                  @export_path = File.expand_path(File.join(@root_path, tmp_filepath))
                end
              end
              if row[0] == 'Measure Directory'
                tmp_filepath = row[1]
                if (Pathname.new tmp_filepath).absolute?
                  @measure_paths << tmp_filepath
                else
                  @measure_paths << File.expand_path(File.join(@root_path, tmp_filepath))
                end
              end
              @run_setup[row[0].to_underscore.to_s] = row[1] if row[0]

              # type cast
              if @run_setup['allow_multiple_jobs']
                raise 'allow_multiple_jobs is no longer a valid option in the Excel file, please delete the row and rerun'
              end
              if @run_setup['use_server_as_worker']
                raise 'use_server_as_worker is no longer a valid option in the Excel file, please delete the row and rerun'
              end
            elsif b_problem_setup
              if row[0]
                v = row[1]
                v.to_i if v % 1 == 0
                @problem[row[0].to_underscore.to_s] = v
              end

            elsif b_algorithm_setup
              if row[0] && !row[0].empty?
                v = row[1]
                v = v.to_i if v % 1 == 0
                @algorithm[row[0].to_underscore.to_s] = v
              end
            elsif b_weather_files
              if row[0] == 'Weather File'
                weather_path = row[1]
                unless (Pathname.new weather_path).absolute?
                  weather_path = File.expand_path(File.join(@root_path, weather_path))
                end
                @weather_paths << weather_path
                @weather_files += Dir.glob(weather_path)
              end
            elsif b_models
              if row[1]
                tmp_m_name = row[1]
              else
                tmp_m_name = SecureRandom.uuid
              end
              # Only add models if the row is flagged
              if row[0]&.casecmp('model')&.zero?
                model_path = row[3]
                unless (Pathname.new model_path).absolute?
                  model_path = File.expand_path(File.join(@root_path, model_path))
                end
                @models << { name: tmp_m_name.to_underscore, display_name: tmp_m_name, type: row[2], path: model_path }
              end
            elsif b_other_libs
              # determine if the path is relative
              other_path = row[2]
              unless (Pathname.new other_path).absolute?
                other_path = File.expand_path(File.join(@root_path, other_path))
              end

              @other_files << { lib_zip_name: row[1], path: other_path }
            elsif b_worker_init
              worker_init_path = row[1]
              unless (Pathname.new worker_init_path).absolute?
                worker_init_path = File.expand_path(File.join(@root_path, worker_init_path))
              end

              @worker_inits << { name: row[0], path: worker_init_path, args: row[2] }
            elsif b_worker_final
              worker_final_path = row[1]
              unless (Pathname.new worker_final_path).absolute?
                worker_final_path = File.expand_path(File.join(@root_path, worker_final_path))
              end

              @worker_finals << { name: row[0], path: worker_final_path, args: row[2] }
            end

            next
          end

          # do some last checks
          @measure_paths = ['./measures'] if @measure_paths.empty?
        end

        # parse_variables will parse the XLS spreadsheet and save the data into
        # a higher level JSON file.  The JSON file is historic and it should really
        # be omitted as an intermediate step
        def parse_variables
          # clean remove whitespace and unicode chars
          # The parse is a unique format (https://github.com/Empact/roo/blob/master/lib/roo/base.rb#L444)
          # If you add a new column and you want that variable in the hash, then you must add it here.
          # rows = @xls.sheet('Variables').parse(:enabled => "# variable")
          # puts rows.inspect

          rows = nil
          begin
            if @version >= '0.3.3'.to_version
              rows = @xls.sheet('Variables').parse(enabled: /# variable/i,
                                                   measure_name_or_var_type: /type/i,
                                                   measure_file_name_or_var_display_name: /parameter\sdisplay\sname.*/i,
                                                   measure_file_name_directory: /measure\sdirectory/i,
                                                   measure_type_or_parameter_name_in_measure: /parameter\sname\sin\smeasure/i,
                                                   display_name_short: /parameter\sshort\sdisplay\sname/i,
                                                   # sampling_method: /sampling\smethod/i,
                                                   variable_type: /variable\stype/i,
                                                   units: /units/i,
                                                   default_value: /static.default\svalue/i,
                                                   enums: /enumerations/i,
                                                   min: /min/i,
                                                   max: /max/i,
                                                   mode: /mean|mode/i,
                                                   stddev: /std\sdev/i,
                                                   delta_x: /delta.x/i,
                                                   discrete_values: /discrete\svalues/i,
                                                   discrete_weights: /discrete\sweights/i,
                                                   distribution: /distribution/i,
                                                   source: /data\ssource/i,
                                                   notes: /notes/i,
                                                   relation_to_eui: /typical\svar\sto\seui\srelationship/i,
                                                   clean: true)
            elsif @version >= '0.3.0'.to_version
              rows = @xls.sheet('Variables').parse(enabled: /# variable/i,
                                                   measure_name_or_var_type: /type/i,
                                                   measure_file_name_or_var_display_name: /parameter\sdisplay\sname.*/i,
                                                   measure_file_name_directory: /measure\sdirectory/i,
                                                   measure_type_or_parameter_name_in_measure: /parameter\sname\sin\smeasure/i,
                                                   # sampling_method: /sampling\smethod/i,
                                                   variable_type: /variable\stype/i,
                                                   units: /units/i,
                                                   default_value: /static.default\svalue/i,
                                                   enums: /enumerations/i,
                                                   min: /min/i,
                                                   max: /max/i,
                                                   mode: /mean|mode/i,
                                                   stddev: /std\sdev/i,
                                                   delta_x: /delta.x/i,
                                                   discrete_values: /discrete\svalues/i,
                                                   discrete_weights: /discrete\sweights/i,
                                                   distribution: /distribution/i,
                                                   source: /data\ssource/i,
                                                   notes: /notes/i,
                                                   relation_to_eui: /typical\svar\sto\seui\srelationship/i,
                                                   clean: true)
            elsif @version >= '0.2.0'.to_version
              rows = @xls.sheet('Variables').parse(enabled: /# variable/i,
                                                   measure_name_or_var_type: /type/i,
                                                   measure_file_name_or_var_display_name: /parameter\sdisplay\sname.*/i,
                                                   measure_file_name_directory: /measure\sdirectory/i,
                                                   measure_type_or_parameter_name_in_measure: /parameter\sname\sin\smeasure/i,
                                                   sampling_method: /sampling\smethod/i,
                                                   variable_type: /variable\stype/i,
                                                   units: /units/i,
                                                   default_value: /static.default\svalue/i,
                                                   enums: /enumerations/i,
                                                   min: /min/i,
                                                   max: /max/i,
                                                   mode: /mean|mode/i,
                                                   stddev: /std\sdev/i,
                                                   delta_x: /delta.x/i,
                                                   discrete_values: /discrete\svalues/i,
                                                   discrete_weights: /discrete\sweights/i,
                                                   distribution: /distribution/i,
                                                   source: /data\ssource/i,
                                                   notes: /notes/i,
                                                   relation_to_eui: /typical\svar\sto\seui\srelationship/i,
                                                   clean: true)
            elsif @version >= '0.1.12'.to_version
              rows = @xls.sheet('Variables').parse(enabled: /# variable/i,
                                                   measure_name_or_var_type: /type/i,
                                                   measure_file_name_or_var_display_name: /parameter\sdisplay\sname.*/i,
                                                   measure_type_or_parameter_name_in_measure: /parameter\sname\sin\smeasure/i,
                                                   sampling_method: /sampling\smethod/i,
                                                   variable_type: /variable\stype/i,
                                                   units: /units/i,
                                                   default_value: /static.default\svalue/i,
                                                   enums: /enumerations/i,
                                                   min: /min/i,
                                                   max: /max/i,
                                                   mode: /mean|mode/i,
                                                   stddev: /std\sdev/i,
                                                   delta_x: /delta.x/i,
                                                   discrete_values: /discrete\svalues/i,
                                                   discrete_weights: /discrete\sweights/i,
                                                   distribution: /distribution/i,
                                                   source: /data\ssource/i,
                                                   notes: /notes/i,
                                                   relation_to_eui: /typical\svar\sto\seui\srelationship/i,
                                                   clean: true)
            elsif @version >= '0.1.11'.to_version
              rows = @xls.sheet('Variables').parse(enabled: /# variable/i,
                                                   measure_name_or_var_type: /type/i,
                                                   measure_file_name_or_var_display_name: /parameter\sdisplay\sname.*/i,
                                                   measure_type_or_parameter_name_in_measure: /parameter\sname\sin\smeasure/i,
                                                   sampling_method: /sampling\smethod/i,
                                                   variable_type: /variable\stype/i,
                                                   units: /units/i,
                                                   default_value: /static.default\svalue/i,
                                                   enums: /enumerations/i,
                                                   min: /min/i,
                                                   max: /max/i,
                                                   mode: /mean|mode/i,
                                                   stddev: /std\sdev/i,
                                                   # delta_x: /delta.x/i,
                                                   discrete_values: /discrete\svalues/i,
                                                   discrete_weights: /discrete\sweights/i,
                                                   distribution: /distribution/i,
                                                   source: /data\ssource/i,
                                                   notes: /notes/i,
                                                   relation_to_eui: /typical\svar\sto\seui\srelationship/i,
                                                   clean: true)
            else
              rows = @xls.sheet('Variables').parse(enabled: /# variable/i,
                                                   measure_name_or_var_type: /type/i,
                                                   measure_file_name_or_var_display_name: /parameter\sdisplay\sname.*/i,
                                                   measure_type_or_parameter_name_in_measure: /parameter\sname\sin\smeasure/i,
                                                   sampling_method: /sampling\smethod/i,
                                                   variable_type: /variable\stype/i,
                                                   units: /units/i,
                                                   default_value: /static.default\svalue/i,
                                                   enums: /enumerations/i,
                                                   min: /min/i,
                                                   max: /max/i,
                                                   mode: /mean|mode/i,
                                                   stddev: /std\sdev/i,
                                                   # delta_x: /delta.x/i,
                                                   # discrete_values: /discrete\svalues/i,
                                                   # discrete_weights: /discrete\sweights/i,
                                                   distribution: /distribution/i,
                                                   source: /data\ssource/i,
                                                   notes: /notes/i,
                                                   relation_to_eui: /typical\svar\sto\seui\srelationship/i,
                                                   clean: true)
            end
          rescue StandardError => e
            raise "Unable to parse spreadsheet #{@xls_filename} with version #{@version} due to error: #{e.message}"
          end

          raise "Could not find the sheet name 'Variables' in excel file #{@root_path}" unless rows

          # map the data to another hash that is more easily processed
          data = {}
          data['data'] = []

          measure_index = -1
          variable_index = -1
          measure_name = nil
          rows.each_with_index do |row, icnt|
            # puts "Parsing line: #{icnt}:#{row}"

            # check if we are a measure - nil means that the cell was blank
            if row[:enabled].nil?
              if measure_name && data['data'][measure_index]['enabled']
                variable_index += 1

                var = {}
                var['variable_type'] = row[:measure_name_or_var_type]
                var['display_name'] = row[:measure_file_name_or_var_display_name]
                var['display_name_short'] = row[:display_name_short] ? row[:display_name_short] : var['display_name']
                var['name'] = row[:measure_type_or_parameter_name_in_measure]
                var['index'] = variable_index # order of the variable (not sure of its need)
                var['type'] = row[:variable_type].downcase
                var['units'] = row[:units]
                var['distribution'] = {}

                # parse the choices/enums
                if var['type'] == 'enum' || var['type'] == 'choice' # this is now a choice
                  if row[:enums]
                    var['distribution']['enumerations'] = row[:enums].delete('|').split(',').map(&:strip)
                  end
                elsif var['type'] == 'bool'
                  var['distribution']['enumerations'] = []
                  var['distribution']['enumerations'] << 'true' # TODO: should this be a real bool?
                  var['distribution']['enumerations'] << 'false'
                end

                var['distribution']['min'] = row[:min]
                var['distribution']['max'] = row[:max]
                var['distribution']['mean'] = row[:mode]
                var['distribution']['stddev'] = row[:stddev]
                var['distribution']['discrete_values'] = row[:discrete_values]
                var['distribution']['discrete_weights'] = row[:discrete_weights]
                var['distribution']['type'] = row[:distribution]
                var['distribution']['static_value'] = row[:default_value]
                var['distribution']['delta_x'] = row[:delta_x]

                # type various values correctly
                var['distribution']['min'] = typecast_value(var['type'], var['distribution']['min'])
                var['distribution']['max'] = typecast_value(var['type'], var['distribution']['max'])
                var['distribution']['mean'] = typecast_value(var['type'], var['distribution']['mean'])
                var['distribution']['stddev'] = typecast_value(var['type'], var['distribution']['stddev'])
                var['distribution']['static_value'] = typecast_value(var['type'], var['distribution']['static_value'])

                # eval the discrete value and weight arrays
                case var['type']
                  when 'bool', 'boolean'
                    if var['distribution']['discrete_values']
                      var['distribution']['discrete_values'] = eval(var['distribution']['discrete_values']).map { |v| v.to_s == 'true' }
                    end
                    if var['distribution']['discrete_weights'] && var['distribution']['discrete_weights'] != ''
                      var['distribution']['discrete_weights'] = eval(var['distribution']['discrete_weights'])
                    end
                  else
                    if var['distribution']['discrete_values']
                      var['distribution']['discrete_values'] = eval(var['distribution']['discrete_values'])
                    end
                    if var['distribution']['discrete_weights'] && var['distribution']['discrete_weights'] != ''
                      var['distribution']['discrete_weights'] = eval(var['distribution']['discrete_weights'])
                    end
                end

                var['distribution']['source'] = row[:source]
                var['notes'] = row[:notes]
                var['relation_to_eui'] = row[:relation_to_eui]

                data['data'][measure_index]['variables'] << var
              end
            else
              measure_index += 1
              variable_index = 0
              data['data'][measure_index] = {}

              # generate name id
              # TODO: put this into a logger. puts "Parsing measure #{row[1]}"
              display_name = row[:measure_name_or_var_type]
              measure_name = display_name.downcase.strip.tr('-', '_').tr(' ', '_').gsub('__', '_')
              data['data'][measure_index]['display_name'] = display_name
              data['data'][measure_index]['name'] = measure_name
              data['data'][measure_index]['enabled'] = row[:enabled]
              data['data'][measure_index]['measure_file_name'] = row[:measure_file_name_or_var_display_name]
              if row[:measure_file_name_directory]
                data['data'][measure_index]['measure_file_name_directory'] = row[:measure_file_name_directory]
              else
                data['data'][measure_index]['measure_file_name_directory'] = row[:measure_file_name_or_var_display_name].to_underscore
              end
              data['data'][measure_index]['measure_type'] = row[:measure_type_or_parameter_name_in_measure]
              data['data'][measure_index]['version'] = @version_id

              data['data'][measure_index]['variables'] = []
            end
          end

          data
        end

        def parse_outputs
          rows = nil
          if @version >= '0.3.3'.to_version
            rows = @xls.sheet('Outputs').parse(display_name: /variable\sdisplay\sname/i,
                                               display_name_short: /short\sdisplay\sname/i,
                                               metadata_id: /taxonomy\sidentifier/i,
                                               name: /^name$/i,
                                               units: /units/i,
                                               visualize: /visualize/i,
                                               export: /export/i,
                                               variable_type: /variable\stype/i,
                                               objective_function: /objective\sfunction/i,
                                               objective_function_target: /objective\sfunction\starget/i,
                                               scaling_factor: /scale/i,
                                               objective_function_group: /objective\sfunction\sgroup/i)
          elsif @version >= '0.3.0'.to_version
            rows = @xls.sheet('Outputs').parse(display_name: /variable\sdisplay\sname/i,
                                               # display_name_short: /short\sdisplay\sname/i,
                                               metadata_id: /taxonomy\sidentifier/i,
                                               name: /^name$/i,
                                               units: /units/i,
                                               visualize: /visualize/i,
                                               export: /export/i,
                                               variable_type: /variable\stype/i,
                                               objective_function: /objective\sfunction/i,
                                               objective_function_target: /objective\sfunction\starget/i,
                                               scaling_factor: /scale/i,
                                               objective_function_group: /objective\sfunction\sgroup/i)
          else
            rows = @xls.sheet('Outputs').parse(display_name: /variable\sdisplay\sname/i,
                                               # display_name_short: /short\sdisplay\sname/i,
                                               # metadata_id: /taxonomy\sidentifier/i,
                                               name: /^name$/i,
                                               units: /units/i,
                                               # visualize: /visualize/i,
                                               # export: /export/i,
                                               # variable_type: /variable\stype/i,
                                               objective_function: /objective\sfunction/i,
                                               objective_function_target: /objective\sfunction\starget/i,
                                               scaling_factor: /scale/i,
                                               objective_function_group: /objective/i)

          end

          unless rows
            raise "Could not find the sheet name 'Outputs' in excel file #{@root_path}"
          end

          data = {}
          data['output_variables'] = []

          variable_index = -1
          group_index = 1

          rows.each_with_index do |row, icnt|
            next if icnt < 1 # skip the first 3 lines of the file

            var = {}
            var['display_name'] = row[:display_name]
            var['display_name_short'] = row[:display_name_short] ? row[:display_name_short] : row[:display_name]
            var['metadata_id'] = row[:metadata_id]
            var['name'] = row[:name]
            var['units'] = row[:units]
            var['visualize'] = row[:visualize]
            var['export'] = row[:export]
            var['variable_type'] = row[:variable_type].downcase if row[:variable_type]
            var['objective_function'] = row[:objective_function]
            var['objective_function_target'] = row[:objective_function_target]
            var['scaling_factor'] = row[:scaling_factor]

            if var['objective_function']
              if row[:objective_function_group].nil?
                var['objective_function_group'] = group_index
                group_index += 1
              else
                var['objective_function_group'] = row[:objective_function_group]
              end
            end
            data['output_variables'] << var
          end

          data
        end
      end
    end
  end
end
