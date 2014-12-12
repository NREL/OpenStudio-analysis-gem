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
        attr_reader :analysis_name
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
          @analysis_name = nil
          @cluster_name = nil
          @settings = {}
          @weather_files = []
          @models = []
          @other_files = []
          @worker_inits = []
          @worker_finals = []
          @export_path = './export'
          @measure_paths = []
          @number_of_samples = 0 # todo: remove this
          @problem = {}
          @algorithm = {}
          @template_json = nil
          @outputs = {}
          @run_setup = {}
          @aws_tags = []
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

        # Save off the legacy format of the JSON file
        def save_variable_json(filename)
          FileUtils.rm_f(filename) if File.exist?(filename)
          File.open(filename, 'w') { |f| f << JSON.pretty_generate(@variables) }
        end

        def validate_analysis
          # Setup the paths and do some error checking
          @measure_paths.each do |mp|
            fail "Measures directory '#{mp}' does not exist" unless Dir.exist?(mp)
          end

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
          @other_files.each do |f|
            fail "Other files do not exist for: #{f[:path]}" unless File.exist?(f[:path])
          end

          @worker_inits.each do |f|
            fail "Worker initialization file does not exist for: #{f[:path]}" unless File.exist?(f[:path])
          end

          @worker_finals.each do |f|
            fail "Worker finalization file does not exist for: #{f[:path]}" unless File.exist?(f[:path])
          end

          FileUtils.mkdir_p(@export_path)

          # verify that the measure display names are unique
          # puts @variables.inspect
          measure_display_names = @variables['data'].map { |m| m['enabled'] ? m['display_name'] : nil }.compact
          measure_display_names_mult = measure_display_names.select { |m| measure_display_names.count(m) > 1 }.uniq
          if measure_display_names_mult && !measure_display_names_mult.empty?
            fail "Measure Display Names are not unique for '#{measure_display_names_mult.join('\', \'')}'"
          end

          # verify that all continuous variables have all the data needed and create a name maps
          variable_names = []
          @variables['data'].each do |measure|
            if measure['enabled']
              measure['variables'].each do |variable|

                # Determine if row is suppose to be an argument or a variable to be perturbed.
                if variable['variable_type'] == 'variable'
                  variable_names << variable['display_name']

                  # make sure that variables have static values
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
            puts "Creating JSON and ZIP file for #{@name}:#{model[:display_name]}"
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
          argument_template = ERB.new(File.read("#{template_root}/argument.json.erb"))

          # Templated analysis json file (this is what is returned)
          openstudio_analysis_json = JSON.parse(analysis_template.result(get_binding))

          openstudio_analysis_json['analysis']['problem'].merge!(@problem)
          openstudio_analysis_json['analysis']['problem']['algorithm'].merge!(@algorithm)
          openstudio_analysis_json['analysis'].merge!(@outputs)

          @measure_index = -1
          @variables['data'].each do |measure|
            # With OpenStudio server we need to create the workflow with all the measure instances
            if measure['enabled']
              @measure_index += 1

              # puts "  Adding measure item '#{measure['name']}' to analysis.json"
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
                    @values_and_weights = @variable['distribution']['enumerations'].map { |v| { value: v } }.to_json
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
                      @values_and_weights = values.zip(weights).map { |v, w| { value: v, weight: w } }.to_json
                    else
                      @values_and_weights = values.map { |v| { value: v } }.to_json
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
            # puts "Add Directory #{local_directory}"
            Dir[File.join("#{local_directory}", '**', '**')].each do |file|
              # puts "Adding File #{file}"
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
            required_measures = @variables['data'].map { |v| v['measure_file_name_directory'] if v['enabled'] }.compact.uniq

            # Convert this into a hash which looks like {name: measure_name}. This will allow us to add more
            # fields to the measure, such as which directory is the measure.
            required_measures = required_measures.map { |value| { name: value } }

            # first validate that all the measures exist
            errors = []
            required_measures.each do |measure|
              next if measure.key? :path

              @measure_paths.each do |measure_path|
                measure_dir_to_add = "#{measure_path}/#{measure[:name]}"
                if Dir.exist? measure_dir_to_add
                  if File.exist? "#{measure_dir_to_add}/measure.rb"
                    measure[:path] = measure_path
                    break
                  else
                    errors << "Measure in directory '#{@measure_path}/#{measure}' did not contain a measure.rb file"
                  end
                end
              end
            end

            # validate that all measures were found
            required_measures.each do |measure|
              unless measure.key? :path
                errors << "Could not find measure '#{measure}' in directory '#{@measure_path}'"
              end
            end

            fail errors.join("\n") unless errors.empty?

            required_measures.each do |measure|
              measure_dir_to_add = "#{measure[:path]}/#{measure[:name]}"
              puts "  Adding measure #{measure_dir_to_add} to zip file"
              Dir[File.join(measure_dir_to_add, '**')].each do |file|
                if File.directory?(file)
                  if File.basename(file) == 'resources' || File.basename(file) == 'lib'
                    add_directory_to_zip(zipfile, file, "./measures/#{measure[:name]}/#{File.basename(file)}")
                  else
                    # puts "Skipping Directory #{File.basename(file)}"
                  end
                else
                  # puts "Adding File #{file}"
                  # added_measures << measure_dir unless added_measures.include? measure_dir
                  zipfile.add(file.sub(measure_dir_to_add, "./measures/#{measure[:name]}/"), file)
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

            # puts "Adding in Worker initialize scripts #{@worker_inits}"
            @worker_inits.each_with_index do |f, index|
              # this is ordered
              f[:ordered_file_name] = "#{index.to_s.rjust(2, '0')}_#{File.basename(f[:path])}"
              f[:index] = index

              zipfile.add(f[:path].sub(f[:path], "./lib/worker_initialize/#{f[:ordered_file_name]}"), f[:path])
              arg_file = "#{File.basename(f[:ordered_file_name], '.*')}.args"
              file = Tempfile.new('arg')
              file.write(f[:args])
              zipfile.add("./lib/worker_initialize/#{arg_file}", file)
              file.close
            end

            # puts "Adding in Worker finalize scripts #{@worker_finals}"
            @worker_finals.each_with_index do |f, index|
              # this is ordered
              f[:ordered_file_name] = "#{index.to_s.rjust(2, '0')}_#{File.basename(f[:path])}"
              f[:index] = index

              zipfile.add(f[:path].sub(f[:path], "./lib/worker_finalize/#{f[:ordered_file_name]}"), f[:path])
              arg_file = "#{File.basename(f[:ordered_file_name], '.*')}.args"
              file = Tempfile.new('arg')
              file.write(f[:args])
              zipfile.add("./lib/worker_finalize/#{arg_file}", file)
              file.close
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
            weather = @weather_files.find { |w| File.extname(w).downcase == '.epw' }
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
              @settings["#{row[0].snake_case}"] = row[1] if row[0]
              @cluster_name = @settings['cluster_name'].snake_case if @settings['cluster_name']

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
                @analysis_name = @name.snake_case
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
              if row[0] && !row[0].empty?
                v = row[1]
                v = v.to_i if v % 1 == 0
                @algorithm["#{row[0].snake_case}"] = v
              end
            elsif b_weather_files
              if row[0] == 'Weather File'
                weather_path = row[1]
                unless (Pathname.new weather_path).absolute?
                  weather_path = File.expand_path(File.join(@root_path, weather_path))
                end
                @weather_files += Dir.glob(weather_path)
              end
            elsif b_models
              if row[1]
                tmp_m_name = row[1]
              else
                tmp_m_name = SecureRandom.uuid
              end
              # Only add models if the row is flagged
              if row[0] && row[0].downcase == 'model'
                model_path = row[3]
                unless (Pathname.new model_path).absolute?
                  model_path = File.expand_path(File.join(@root_path, model_path))
                end
                @models << { name: tmp_m_name.snake_case, display_name: tmp_m_name, type: row[2], path: model_path }
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
              rows = @xls.sheet('Variables').parse(enabled: '# variable',
                                                   measure_name_or_var_type: 'type',
                                                   measure_file_name_or_var_display_name: 'parameter display name.*',
                                                   measure_file_name_directory: 'measure directory',
                                                   measure_type_or_parameter_name_in_measure: 'parameter name in measure',
                                                   display_name_short: 'parameter short display name',
                                                   # sampling_method: 'sampling method',
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
            elsif @version >= '0.3.0'.to_version
              rows = @xls.sheet('Variables').parse(enabled: '# variable',
                                                   measure_name_or_var_type: 'type',
                                                   measure_file_name_or_var_display_name: 'parameter display name.*',
                                                   measure_file_name_directory: 'measure directory',
                                                   measure_type_or_parameter_name_in_measure: 'parameter name in measure',
                                                   # sampling_method: 'sampling method',
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
          rescue => e
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
                var['display_name_short'] = row[:display_name_short] ? row[:display_name_short] : var['display_name']
                var['name'] = row[:measure_type_or_parameter_name_in_measure]
                var['index'] = variable_index # order of the variable (not sure of its need)
                var['type'] = row[:variable_type] ? row[:variable_type].downcase : row[:variable_type]
                var['units'] = row[:units]
                var['distribution'] = {}

                # parse the choices/enums
                if var['type'] == 'enum' || var['type'] == 'choice' # this is now a choice
                  var['distribution']['enumerations'] = row[:enums].gsub('|', '').split(',').map(&:strip)
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
              measure_name = display_name.downcase.strip.gsub('-', '_').gsub(' ', '_').gsub('__', '_')
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
          if @version >= '0.3.3'.to_version
            rows = @xls.sheet('Outputs').parse(display_name: 'Variable Display Name',
                                               display_name_short: 'Short Display Name',
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
          elsif @version >= '0.3.0'.to_version
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
            var['display_name_short'] = row[:display_name_short] ? row[:display_name_short] : row[:display_name]
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
