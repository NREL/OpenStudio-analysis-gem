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
        attr_reader :measure_path
        attr_reader :export_path
        attr_reader :cluster_name
        attr_reader :variables
        attr_reader :algorithm
        attr_reader :problem
        attr_reader :run_setup

        # remove these once we have classes to construct the JSON file
        attr_accessor :name
        attr_reader :machine_name
        attr_reader :template_json

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
            fail "File #{@xls_filename} does not exist"
          end

          # Initialize some other instance variables
          @version = '0.0.1'
          @name = nil
          @machine_name = nil
          @cluster_name = nil
          @settings = {}
          @weather_files = []
          @models = []
          @other_files = []
          @export_path = './export'
          @measure_path = './measures'
          @number_of_samples = 0 # todo: remove this
          @problem = {}
          @algorithm = {}
          @template_json = nil
          @outputs = {}
          @run_setup = {}
        end

        def process
          @setup = parse_setup

          @version = Semantic::Version.new @version
          fail "Spreadsheet version #{@version} is no longer supported.  Please upgrade your spreadsheet to at least 0.1.9" if @version < '0.1.9'

          @variables = parse_variables

          @outputs = parse_outputs

          # call validate to make sure everything that is needed exists (i.e. directories)
          validate_analysis
        end

        # Save off the legacy format of the JSON file
        def save_variable_json(filename)
          FileUtils.rm_f(filename) if File.exist?(filename)
          File.open(filename, 'w') { |f| f << JSON.pretty_generate(@variables) }
        end

        def validate_analysis
          # Setup the paths and do some error checking
          fail "Measures directory '#{@measure_path}' does not exist" unless Dir.exist?(@measure_path)

          @models.uniq!
          fail 'No seed models defined in spreadsheet' if @models.empty?

          @models.each do |model|
            fail "Seed model does not exist: #{model[:path]}" unless File.exist?(model[:path])
          end

          @weather_files.uniq!
          fail 'No weather files found based on what is in the spreadsheet' if @weather_files.empty?

          @weather_files.each do |wf|
            fail "Weather file does not exist: #{wf}" unless File.exist?(wf)
          end

          # This can be a directory as well
          @other_files.each do |of|
            fail "Other files do not exist for: #{of[:path]}" unless File.exist?(of[:path])
          end

          FileUtils.mkdir_p(@export_path)

          # verify that all continuous variables have all the data needed and create a name maps
          variable_names = []
          @variables['data'].each do |measure|
            if measure['enabled']
              measure['variables'].each do |variable|
                # Determine if row is suppose to be an argument or a variable to be perturbed.
                if variable['variable_type'] == 'variable'
                  variable_names << variable['display_name']

                  # make sure that the variable has a static value
                  if variable['distribution']['static_value'].nil? || variable['distribution']['static_value'] == ''
                    fail "Variable #{measure['name']}:#{variable['name']} needs a static value"
                  end

                  if variable['type'] == 'enum' || variable['type'] == 'Choice'
                    # check something
                  else # must be an integer or double
                    if variable['distribution']['type'] == 'discrete_uncertain'
                      if variable['distribution']['discrete_values'].nil? || variable['distribution']['discrete_values'] == ''
                        fail "Variable #{measure['name']}:#{variable['name']} needs discrete values"
                      end
                    else
                      if variable['distribution']['mean'].nil? || variable['distribution']['mean'] == ''
                        fail "Variable #{measure['name']}:#{variable['name']} must have a mean"
                      end
                      if variable['distribution']['stddev'].nil? || variable['distribution']['stddev'] == ''
                        fail "Variable #{measure['name']}:#{variable['name']} must have a stddev"
                      end
                    end

                    if variable['distribution']['mean'].nil? || variable['distribution']['mean'] == ''
                      fail "Variable #{measure['name']}:#{variable['name']} must have a mean/mode"
                    end
                    if variable['distribution']['min'].nil? || variable['distribution']['min'] == ''
                      fail "Variable #{measure['name']}:#{variable['name']} must have a minimum"
                    end
                    if variable['distribution']['max'].nil? || variable['distribution']['max'] == ''
                      fail "Variable #{measure['name']}:#{variable['name']} must have a maximum"
                    end
                    unless variable['type'] == 'string'
                      if variable['distribution']['min'] > variable['distribution']['max']
                        fail "Variable min is greater than variable max for #{measure['name']}:#{variable['name']}"
                      end
                    end

                  end
                end
              end
            end
          end

          dupes = variable_names.select { |e| variable_names.count(e) > 1 }.uniq
          if dupes.count > 0
            fail "duplicate variable names found in list #{dupes.inspect}"
          end

          # most of the checks will raise a runtime exception, so this true will never be called
          true
        end

        def create_analysis_hash
          # save the format in the OpenStudio analysis json format template without
          # the correct weather files or models
          @template_json = translate_to_analysis_json_template

          @template_json
        end

        # save_analysis will iterate over each model that is defined in the spreadsheet and save the
        # zip and json file.
        def save_analysis
          @template_json = create_analysis_hash

          # validate_template_json

          # iterate over each model and save the zip and json
          @models.each do |model|
            save_analysis_zip(model)
            analysis_json = create_analysis_json(@template_json, model, @models.count > 1)
          end
        end

        # TODO: move this into a new class that helps construct this file
        def translate_to_analysis_json_template
          # Load in the templates for constructing the JSON file
          template_root = File.join(File.dirname(__FILE__), '../../templates')
          analysis_template = ERB.new(File.open("#{template_root}/analysis.json.erb", 'r').read)
          workflow_template = ERB.new(File.open("#{template_root}/workflow_item.json.erb", 'r').read)
          uncertain_variable_template = ERB.new(File.open("#{template_root}/uncertain_variable.json.erb", 'r').read)
          discrete_uncertain_variable_template = ERB.new(File.open("#{template_root}/discrete_uncertain_variable.json.erb", 'r').read)
          pivot_variable_template = ERB.new(File.open("#{template_root}/pivot_variable.json.erb", 'r').read)
          argument_template = ERB.new(File.open("#{template_root}/argument.json.erb", 'r').read)

          # Templated analysis json file (this is what is returned)
          puts "Analysis name is #{@name}"
          openstudio_analysis_json = JSON.parse(analysis_template.result(get_binding))

          openstudio_analysis_json['analysis']['problem'].merge!(@problem)
          openstudio_analysis_json['analysis']['problem']['algorithm'].merge!(@algorithm)
          openstudio_analysis_json['analysis'].merge!(@outputs)

          @measure_index = -1
          @variables['data'].each do |measure|
            # With OpenStudio server we need to create the workflow with all the measure instances
            if measure['enabled']
              @measure_index += 1

              puts "  Adding measure item '#{measure['name']}'"
              @measure = measure
              @measure['measure_file_name_dir'] = @measure['measure_file_name'].underscore

              # Grab the measure json file out of the right directory
              wf = JSON.parse(workflow_template.result(get_binding))

              # add in the variables
              measure['variables'].each do |variable|
                @variable = variable
                # Determine if row is suppose to be an argument or a variable to be perturbed.
                if @variable['variable_type'] == 'argument'
                  ag = nil
                  if @variable['distribution']['static_value'].nil? || @variable['distribution']['static_value'] == 'null'
                    puts "    Warning: '#{measure['name']}:#{@variable['name']}' static value was empty or null, assuming optional and skipping"
                    next
                  end

                  # add this as an argument
                  case @variable['type'].downcase
                    when 'double'
                      @static_value = @variable['distribution']['static_value'].to_f
                    when 'integer'
                      @static_value = @variable['distribution']['static_value'].to_i
                    # TODO: update openstudio export to write only Strings
                    when 'string', 'choice'
                      @static_value = @variable['distribution']['static_value'].inspect
                    when 'bool'
                      if @variable['distribution']['static_value'].downcase == 'true'
                        @static_value = true
                      else
                        @static_value = false
                      end
                    else
                      fail "Unknown variable type of '#{@variable['type']}'"
                  end
                  ag = JSON.parse(argument_template.result(get_binding))
                  fail "Argument '#{@variable['name']}' did not process.  Most likely it did not have all parameters defined." if ag.nil?
                  wf['arguments'] << ag
                else # must be a variable [either pivot or normal variable]
                  vr = nil
                  # add this as an argument
                  case @variable['type'].downcase
                    when 'double'
                      @static_value = @variable['distribution']['static_value'].to_f
                    when 'integer'
                      @static_value = @variable['distribution']['static_value'].to_i
                    # TODO: update openstudio export to write only Strings
                    when 'string', 'choice'
                      @static_value = @variable['distribution']['static_value'].inspect
                    when 'bool'
                      if @variable['distribution']['static_value'].downcase == 'true'
                        @static_value = true
                      else
                        @static_value = false
                      end
                    else
                      fail "Unknown variable type of '#{@variable['type']}'"
                  end

                  # TODO: remove enum and choice as this is not the variable type
                  if @variable['type'] == 'enum' || @variable['type'].downcase == 'choice'
                    @values_and_weights = @variable['distribution']['enumerations'].map { |v| {value: v} }.to_json
                    vr = JSON.parse(discrete_uncertain_variable_template.result(get_binding))
                  elsif @variable['distribution']['type'] == 'discrete_uncertain'
                    # puts @variable.inspect
                    weights = nil
                    if @variable['distribution']['discrete_weights'] && @variable['distribution']['discrete_weights'] != ''
                      weights = eval(@variable['distribution']['discrete_weights'])
                    end

                    values = nil
                    if variable['type'].downcase == 'bool'
                      values = eval(@variable['distribution']['discrete_values'])
                      values.map! { |v| v.to_s == 'true' }
                    else
                      values = eval(@variable['distribution']['discrete_values'])
                    end

                    if weights
                      fail "Discrete variable '#{@variable['name']}' does not have equal length of values and weights" if values.size != weights.size
                      @values_and_weights = values.zip(weights).map { |v, w| {value: v, weight: w} }.to_json
                    else
                      @values_and_weights = values.map { |v| {value: v} }.to_json
                    end


                    if @variable['variable_type'] == 'pivot'

                      vr = JSON.parse(pivot_variable_template.result(get_binding))
                    else
                      vr = JSON.parse(discrete_uncertain_variable_template.result(get_binding))
                    end
                  else
                    if @variable['variable_type'] == 'pivot'
                      fail 'Currently unable to pivot on continuous variables... stay tuned.'
                    else
                      vr = JSON.parse(uncertain_variable_template.result(get_binding))
                    end
                  end
                  fail 'variable was nil after processing' if vr.nil?
                  wf['variables'] << vr
                end
              end

              openstudio_analysis_json['analysis']['problem']['workflow'] << wf
            end
          end

          openstudio_analysis_json
        end

        protected

        # helper method for ERB
        def get_binding
          binding
        end

        # Package up the seed, weather files, and measures
        def save_analysis_zip(model)
          def add_directory_to_zip(zipfile, local_directory, relative_zip_directory)
            # pp "Add Directory #{local_directory}"
            Dir[File.join("#{local_directory}", '**', '**')].each do |file|
              # pp "Adding File #{file}"
              zipfile.add(file.sub(local_directory, relative_zip_directory), file)
            end
            zipfile
          end

          zipfile_name = "#{@export_path}/#{model[:name]}.zip"
          FileUtils.rm_f(zipfile_name) if File.exist?(zipfile_name)

          Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
            @weather_files.each do |filename|
              # puts "  Adding #{filename}"
              zipfile.add("./weather/#{File.basename(filename)}", filename)
            end

            # Add only the measures that are defined in the spreadsheet
            added_measures = []
            measure_files = Dir.glob("#{@measure_path}/**/measure.rb")

            # go through each of the Variables
            @variables['data'].each do |v|
              measure_to_save = nil
              measure_files.each do |measure|
                # pp v['measure_file_name_directory']
                if measure.include? "/#{v['measure_file_name_directory']}/"
                  measure_to_save = File.dirname(measure)
                  # pp "Measure to save is #{measure}"
                  break
                end
              end

              if measure_to_save && !added_measures.include?(measure_to_save)
                # pp "Attempting to add measure #{measure_to_save}"
                if File.exist?(measure_to_save)
                  # pp "Adding measure directory to zip #{measure_to_save}"
                  Dir[File.join(measure_to_save, '**')].each do |file|
                    if File.directory?(file)
                      if File.basename(file) == 'resources' || File.basename(file) == 'lib'
                        add_directory_to_zip(zipfile, file, "./measures/#{v['measure_file_name_directory']}/#{File.basename(file)}")
                      else
                        # pp "Skipping Directory #{File.basename(file)}"
                      end
                    else
                      # pp "Adding File #{file}"
                      # added_measures << measure_dir unless added_measures.include? measure_dir
                      zipfile.add(file.sub(measure_to_save, "./measures/#{v['measure_file_name_directory']}/"), file)
                    end
                  end
                  added_measures << measure_to_save unless added_measures.include? measure_to_save
                else
                  fail "Could not find measure to add to zip for #{@measure_path}/#{v['measure_file_name_directory']}"
                end
              end
            end

            # puts "Adding #{model[:path]}"
            zipfile.add("./seed/#{File.basename(model[:path])}", model[:path])

            # puts "Adding in other files #{@other_files.inspect}"
            @other_files.each do |others|
              Dir[File.join(others[:path], '**', '**')].each do |file|
                zipfile.add(file.sub(others[:path], "./lib/#{others[:lib_zip_name]}/"), file)
              end
            end
          end
        end

        def create_analysis_json(analysis_json, model, append_model_name)
          def deep_copy(o)
            Marshal.load(Marshal.dump(o))
          end

          # append the model name to the analysis name if requested (normally if there are more than
          # 1 models in the spreadsheet)
          new_analysis_json = deep_copy(analysis_json)
          if append_model_name
            new_analysis_json['analysis']['display_name'] = new_analysis_json['analysis']['display_name'] + ' - ' + model[:display_name]
            new_analysis_json['analysis']['name'] = new_analysis_json['analysis']['name'] + '_' + model[:name]
          end

          # Set the seed model in the analysis_json
          new_analysis_json['analysis']['seed']['file_type'] = model[:type]
          # This is the path that will be seen on the server when this runs
          new_analysis_json['analysis']['seed']['path'] = "./seed/#{File.basename(model[:path])}"

          # Set the weather file as the first in the list -- this is optional
          new_analysis_json['analysis']['weather_file']['file_type'].downcase == 'epw'
          if File.extname(@weather_files.first) =~ /.zip/i
            new_analysis_json['analysis']['weather_file']['path'] = "./weather/#{File.basename(@weather_files.first, '.zip')}.epw"
          else
            # get the first EPW file (not the first file)
            weather = @weather_files.find{|w| File.extname(w).downcase == '.epw'}
            fail "Could not find a weather file (*.epw) in weather directory #{File.dirname(@weather_files.first)}" unless weather
            new_analysis_json['analysis']['weather_file']['path'] = "./weather/#{File.basename(weather)}"
          end

          json_file_name = "#{@export_path}/#{model[:name]}.json"
          FileUtils.rm_f(json_file_name) if File.exist?(json_file_name)
          File.open(json_file_name, 'w') { |f| f << JSON.pretty_generate(new_analysis_json) }
        end

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

          rows.each do |row|
            if row[0] == 'Settings'
              b_settings = true
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              next
            elsif row[0] == 'Running Setup'
              b_settings = false
              b_run_setup = true
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              next
            elsif row[0] == 'Problem Definition'
              b_settings = false
              b_run_setup = false
              b_problem_setup = true
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              next
            elsif row[0] == 'Algorithm Setup'
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = true
              b_weather_files = false
              b_models = false
              b_other_libs = false
              next
            elsif row[0] == 'Weather Files'
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = true
              b_models = false
              b_other_libs = false
              next
            elsif row[0] == 'Models'
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = true
              b_other_libs = false
              next
            elsif row[0] == 'Other Library Files'
              b_settings = false
              b_run_setup = false
              b_problem_setup = false
              b_algorithm_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = true
              next
            end

            next if row[0].nil?

            if b_settings
              @version = row[1].chomp if row[0] == 'Spreadsheet Version'
              @settings["#{row[0].snake_case}"] = row[1] if row[0]
              @cluster_name = @settings['cluster_name'].snake_case if @settings['cluster_name']

              # type some of the values that we know
              @settings['proxy_port'] = @settings['proxy_port'].to_i if @settings['proxy_port']
            elsif b_run_setup
              if row[0] == 'Analysis Name'
                if row[1]
                  @name = row[1]
                else
                  @name = UUID.new.generate
                end
                @machine_name = @name.snake_case
              end
              @export_path = File.expand_path(File.join(@root_path, row[1])) if row[0] == 'Export Directory'
              if row[0] == 'Measure Directory'
                tmp_filepath = row[1]
                if (Pathname.new tmp_filepath).absolute?
                  @measure_path = tmp_filepath
                else
                  @measure_path = File.expand_path(File.join(@root_path, tmp_filepath))
                end
              end
              @run_setup["#{row[0].snake_case}"] = row[1] if row[0]

              # type cast
              @run_setup['allow_multiple_jobs'] = @run_setup['allow_multiple_jobs'].to_s.to_bool if @run_setup['allow_multiple_jobs']
              @run_setup['use_server_as_worker'] = @run_setup['use_server_as_worker'].to_s.to_bool if @run_setup['use_server_as_worker']

            elsif b_problem_setup
              if row[0]
                v = row[1]
                v.to_i if v % 1 == 0
                @problem["#{row[0].snake_case}"] = v
              end

            elsif b_algorithm_setup
              if row[0]
                v = row[1]
                v = v.to_i if v % 1 == 0
                @algorithm["#{row[0].snake_case}"] = v
              end
            elsif b_weather_files
              if row[0] == 'Weather File'
                @weather_files += Dir.glob(File.expand_path(File.join(@root_path, row[1])))
              end
            elsif b_models
              if row[1]
                tmp_m_name = row[1]
              else
                tmp_m_name = UUID.new.generate
              end
              # Only add models if the row is flagged
              if row[0] && row[0].downcase == 'model'
                @models << {name: tmp_m_name.snake_case, display_name: tmp_m_name, type: row[2], path: File.expand_path(File.join(@root_path, row[3]))}
              end
            elsif b_other_libs
              @other_files << {lib_zip_name: row[1], path: row[2]}
            end
          end
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
            if @version >= '0.3.0'.to_version
              rows = @xls.sheet('Variables').parse(enabled: '# variable',
                                                   measure_name_or_var_type: 'type',
                                                   measure_file_name_or_var_display_name: 'parameter display name.*',
                                                   measure_file_name_directory: 'measure directory',
                                                   measure_type_or_parameter_name_in_measure: 'parameter name in measure',
                                                   #sampling_method: 'sampling method',
                                                   variable_type: 'Variable Type',
                                                   units: 'units',
                                                   default_value: 'static.default value',
                                                   enums: 'enumerations',
                                                   min: 'min',
                                                   max: 'max',
                                                   mode: 'mean|mode',
                                                   stddev: 'std dev',
                                                   delta_x: 'delta.x',
                                                   discrete_values: 'discrete values',
                                                   discrete_weights: 'discrete weights',
                                                   distribution: 'distribution',
                                                   source: 'data source',
                                                   notes: 'notes',
                                                   relation_to_eui: 'typical var to eui relationship',
                                                   clean: true)
            elsif @version >= '0.2.0'.to_version
              rows = @xls.sheet('Variables').parse(enabled: '# variable',
                                                   measure_name_or_var_type: 'type',
                                                   measure_file_name_or_var_display_name: 'parameter display name.*',
                                                   measure_file_name_directory: 'measure directory',
                                                   measure_type_or_parameter_name_in_measure: 'parameter name in measure',
                                                   sampling_method: 'sampling method',
                                                   variable_type: 'Variable Type',
                                                   units: 'units',
                                                   default_value: 'static.default value',
                                                   enums: 'enumerations',
                                                   min: 'min',
                                                   max: 'max',
                                                   mode: 'mean|mode',
                                                   stddev: 'std dev',
                                                   delta_x: 'delta.x',
                                                   discrete_values: 'discrete values',
                                                   discrete_weights: 'discrete weights',
                                                   distribution: 'distribution',
                                                   source: 'data source',
                                                   notes: 'notes',
                                                   relation_to_eui: 'typical var to eui relationship',
                                                   clean: true)
            elsif @version >= '0.1.12'.to_version
              rows = @xls.sheet('Variables').parse(enabled: '# variable',
                                                   measure_name_or_var_type: 'type',
                                                   measure_file_name_or_var_display_name: 'parameter display name.*',
                                                   measure_type_or_parameter_name_in_measure: 'parameter name in measure',
                                                   sampling_method: 'sampling method',
                                                   variable_type: 'Variable Type',
                                                   units: 'units',
                                                   default_value: 'static.default value',
                                                   enums: 'enumerations',
                                                   min: 'min',
                                                   max: 'max',
                                                   mode: 'mean|mode',
                                                   stddev: 'std dev',
                                                   delta_x: 'delta.x',
                                                   discrete_values: 'discrete values',
                                                   discrete_weights: 'discrete weights',
                                                   distribution: 'distribution',
                                                   source: 'data source',
                                                   notes: 'notes',
                                                   relation_to_eui: 'typical var to eui relationship',
                                                   clean: true)
            elsif @version >= '0.1.11'.to_version
              rows = @xls.sheet('Variables').parse(enabled: '# variable',
                                                   measure_name_or_var_type: 'type',
                                                   measure_file_name_or_var_display_name: 'parameter display name.*',
                                                   measure_type_or_parameter_name_in_measure: 'parameter name in measure',
                                                   sampling_method: 'sampling method',
                                                   variable_type: 'Variable Type',
                                                   units: 'units',
                                                   default_value: 'static.default value',
                                                   enums: 'enumerations',
                                                   min: 'min',
                                                   max: 'max',
                                                   mode: 'mean|mode',
                                                   stddev: 'std dev',
                                                   #:delta_x => 'delta.x',
                                                   discrete_values: 'discrete values',
                                                   discrete_weights: 'discrete weights',
                                                   distribution: 'distribution',
                                                   source: 'data source',
                                                   notes: 'notes',
                                                   relation_to_eui: 'typical var to eui relationship',
                                                   clean: true)
            else
              rows = @xls.sheet('Variables').parse(enabled: '# variable',
                                                   measure_name_or_var_type: 'type',
                                                   measure_file_name_or_var_display_name: 'parameter display name.*',
                                                   measure_type_or_parameter_name_in_measure: 'parameter name in measure',
                                                   sampling_method: 'sampling method',
                                                   variable_type: 'Variable Type',
                                                   units: 'units',
                                                   default_value: 'static.default value',
                                                   enums: 'enumerations',
                                                   min: 'min',
                                                   max: 'max',
                                                   mode: 'mean|mode',
                                                   stddev: 'std dev',
                                                   #:delta_x => 'delta.x',
                                                   #:discrete_values => 'discrete values',
                                                   #:discrete_weights => 'discrete weights',
                                                   distribution: 'distribution',
                                                   source: 'data source',
                                                   notes: 'notes',
                                                   relation_to_eui: 'typical var to eui relationship',
                                                   clean: true)
            end
          rescue Exception => e
            raise "#{e.message} with Spreadsheet #{@xls_filename} with Version #{@version}  "
          end

          fail "Could not find the sheet name 'Variables' in excel file #{@root_path}" unless rows

          # map the data to another hash that is more easily processed
          data = {}
          data['data'] = []

          measure_index = -1
          variable_index = -1
          measure_name = nil
          rows.each_with_index do |row, icnt|
            next if icnt < 1 # skip the first line after the header
            # puts "Parsing line: #{icnt}:#{row}"

            # check if we are a measure - nil means that the cell was blank
            if row[:enabled].nil?
              unless measure_name.nil?
                variable_index += 1

                var = {}
                var['variable_type'] = row[:measure_name_or_var_type]
                var['display_name'] = row[:measure_file_name_or_var_display_name]
                var['machine_name'] = row[:measure_file_name_or_var_display_name].downcase.strip.gsub('-', '_').gsub(' ', '_').strip
                var['name'] = row[:measure_type_or_parameter_name_in_measure]
                var['index'] = variable_index # order of the variable (not sure of its need)

                var['type'] = row[:variable_type] ? row[:variable_type].downcase : row[:variable_type]
                var['units'] = row[:units]

                var['distribution'] = {}

                # parse the choices/enums
                if var['type'] == 'enum' || var['type'] == 'choice' # this is now a choice
                  var['distribution']['enumerations'] = row[:enums].gsub('|', '').split(',').map { |v| v.strip }
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
              measure_name = display_name.downcase.strip.gsub('-', '_').gsub(' ', '_')
              data['data'][measure_index]['display_name'] = display_name
              data['data'][measure_index]['name'] = measure_name
              data['data'][measure_index]['enabled'] = row[:enabled] == 'TRUE' ? true : false
              data['data'][measure_index]['measure_file_name'] = row[:measure_file_name_or_var_display_name]
              if row[:measure_file_name_directory]
                data['data'][measure_index]['measure_file_name_directory'] = row[:measure_file_name_directory]
              else
                data['data'][measure_index]['measure_file_name_directory'] = row[:measure_file_name_or_var_display_name].underscore
              end
              data['data'][measure_index]['measure_type'] = row[:measure_type_or_parameter_name_in_measure]
              data['data'][measure_index]['version'] = @version_id

              data['data'][measure_index]['variables'] = []
            end
          end

          # puts data.inspect
          data
        end

        def parse_outputs
          rows = nil
          if @version >= '0.3.0'.to_version
            rows = @xls.sheet('Outputs').parse(display_name: 'Variable Display Name',
                                               metadata_id: 'Taxonomy Identifier',
                                               name: '^Name$',
                                               units: 'Units',
                                               visualize: 'Visualize',
                                               export: 'Export',
                                               variable_type: 'Variable Type',
                                               objective_function: 'Objective Function',
                                               objective_function_target: 'Objective Function Target',
                                               scaling_factor: 'Scale',
                                               objective_function_group: 'Objective Function Group')
          else
            rows = @xls.sheet('Outputs').parse(display_name: 'Variable Display Name',
                                               name: '^Name$',
                                               units: 'units',
                                               objective_function: 'objective function',
                                               objective_function_target: 'objective function target',
                                               scaling_factor: 'scale',
                                               objective_function_group: 'objective')
          end

          unless rows
            fail "Could not find the sheet name 'Outputs' in excel file #{@root_path}"
          end

          data = {}
          data['output_variables'] = []

          variable_index = -1
          group_index = 1
          @algorithm['objective_functions'] = []

          rows.each_with_index do |row, icnt|
            next if icnt < 2 # skip the first 3 lines of the file

            var = {}
            var['display_name'] = row[:display_name]
            var['metadata_id'] = row[:metadata_id]
            var['name'] = row[:name]
            var['units'] = row[:units]
            var['visualize'] = row[:visualize].downcase == 'true' ? true : false if row[:visualize]
            var['export'] = row[:export].downcase == 'true' ? true : false if row[:export]
            var['variable_type'] = row[:variable_type] if row[:variable_type]
            var['objective_function'] = row[:objective_function].downcase == 'true' ? true : false
            if var['objective_function']
              @algorithm['objective_functions'] << var['name']
              variable_index += 1
              var['objective_function_index'] = variable_index
            else
              var['objective_function_index'] = nil
            end
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
