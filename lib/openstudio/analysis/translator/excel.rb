module OpenStudio
  module Analysis
    module Translator
      class Excel
        attr_reader :variables
        attr_reader :models
        attr_reader :weather_files
        attr_reader :measure_path
        attr_reader :export_path
        attr_reader :variables
        
        # remove these once we have classes to construct the JSON file
        attr_reader :name
        attr_reader :number_of_samples
        attr_reader :template_json

        # methods to override instance variables
        
        # pass in the filename to read
        def initialize(xls_filename)
          @root_path = File.expand_path(File.dirname(xls_filename))

          @xls = nil
          # try to read the spreadsheet as a roo object
          if File.exists?(xls_filename)
            @xls = Roo::Spreadsheet.open(xls_filename)
          else
            raise "File #{xls_filename} does not exist"
          end

          # Initialize some other instance variables
          @weather_files = []
          @models = []
          @other_files = []
          @export_path = "./export"
          @measure_path = "./measures"
          @number_of_samples = 0
          @template_json = nil
        end
        
        def process
          @setup = parse_setup()
          @variables = parse_variables()

          # call validate to make sure everything that is needed exists (i.e. directories)          
          validate_analysis()
        end

        # Save off the legacy format of the JSON file
        def save_variable_json(filename)
          FileUtils.rm_f(filename) if File.exists?(filename)
          File.open(filename, 'w') { |f| f << JSON.pretty_generate(@variables) }
        end

        def validate_analysis
          # Setup the paths and do some error checking
          raise "Measures directory '#{@measure_path}' does not exist" unless Dir.exists?(@measure_path)

          @models.uniq!
          raise "No seed models defined in spreadsheet" if @models.empty?

          @models.each do |model|
            raise "Seed model does not exist: #{model[:path]}" unless File.exists?(model[:path])
          end

          @weather_files.uniq!
          raise "No weather files found based on what is in the spreadsheet" if @weather_files.empty?

          @weather_files.each do |wf|
            raise "Weather file does not exist: #{wf}" unless File.exists?(wf)
          end

          # This can be a directory as well
          @other_files.each do |of|
            raise "Other files do not exist for: #{of[:path]}" unless File.exists?(of[:path])
          end

          FileUtils.mkdir_p(@export_path)
          
          # verify that all continuous variables have all the data needed and create a name maps
          variable_names = []
          @variables['data'].each do |measure|
            if measure['enabled'] && measure['name'] != 'baseline'
              measure['variables'].each do |variable|
                # Determine if row is suppose to be an argument or a variable to be perturbed.
                if variable['variable_type'] == 'variable'
                  variable_names << variable['display_name']
                  if variable['method'] == 'static'
                    # add this as an argument
                    # check something
                  elsif variable['method'] == 'lhs'
                    if variable['type'] == 'enum'
                      # check something
                    else # must be an integer or double
                      if variable['distribution']['min'].nil? || variable['distribution']['min'] == ""
                        raise "Variable #{measure['name']}:#{variable['name']} must have a minimum"
                      end
                      if variable['distribution']['max'].nil? || variable['distribution']['max'] == ""
                        raise "Variable #{measure['name']}:#{variable['name']} must have a maximum"
                      end
                      if variable['distribution']['mean'].nil? || variable['distribution']['mean'] == ""
                        raise "Variable #{measure['name']}:#{variable['name']} must have a mean"
                      end
                      if variable['distribution']['stddev'].nil? || variable['distribution']['stddev'] == ""
                        raise "Variable #{measure['name']}:#{variable['name']} must have a stddev"
                      end
                      if variable['distribution']['min'] > variable['distribution']['max']
                        raise "Variable min is greater than variable max for #{measure['name']}:#{variable['name']}"
                      end
                    end
                  elsif variable['method'] == 'pivot'
                    # check something
                  end
                end
              end
            end
          end

          dupes = variable_names.find_all { |e| variable_names.count(e) > 1 }.uniq
          if dupes.count > 0
            raise "duplicate variable names found in list #{dupes.inspect}"
          end
          
          # most of the checks will raise a runtime exception, so this true will never be called
          true
        end

        def save_analysis
          # save the format in the OpenStudio analysis json format template without
          # the correct weather files or models
          @template_json = translate_to_analysis_json_template()
          
          #validate_template_json

          # iterate over each model and save the zip and json
          @models.each do |model|
            save_analysis_zip(model)
            analysis_json = create_analysis_json(@template_json, model)
          end
        end

        # TODO: move this into a new class that helps construct this file
        def translate_to_analysis_json_template
          # Load in the templates for constructing the JSON file
          template_root = File.join(File.dirname(__FILE__), "../../templates")
          analysis_template = ERB.new(File.open("#{template_root}/analysis.json.erb", 'r').read)
          workflow_template = ERB.new(File.open("#{template_root}/workflow_item.json.erb", 'r').read)
          uncertain_variable_template = ERB.new(File.open("#{template_root}/uncertain_variable.json.erb", 'r').read)
          discrete_uncertain_variable_template = ERB.new(File.open("#{template_root}/discrete_uncertain_variable.json.erb", 'r').read)
          static_variable_template = ERB.new(File.open("#{template_root}/static_variable.json.erb", 'r').read)
          pivot_variable_template = ERB.new(File.open("#{template_root}/pivot_variable.json.erb", 'r').read)
          argument_template = ERB.new(File.open("#{template_root}/argument.json.erb", 'r').read)

          # Templated analysis json file (this is what is returned)
          puts "Analysis name is #{@name}"
          openstudio_analysis_json = JSON.parse(analysis_template.result(get_binding))

          @measure_index = -1
          @variables['data'].each do |measure|
            # With OpenStudio server we need to create the workflow with all the measure instances
            if measure['enabled'] && measure['name'] != 'baseline'
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
                  if @variable['method'] == 'static'
                    if !@variable['distribution']['static_value']
                      raise "can not have an argument that is not a static value defined in which to set the argument"
                    end

                    # add this as an argument
                    case @variable['type']
                      when "Double"
                        @static_value = @variable['distribution']['static_value'].to_f
                      when "Integer"
                        @static_value = @variable['distribution']['static_value'].to_i
                      when "String", "Choice"
                        @static_value = @variable['distribution']['static_value'].inspect
                      when "Bool"
                        if @variable['distribution']['static_value'].downcase == "true"
                          @static_value = true
                        else
                          @static_value = false
                        end
                      else
                        raise "Unknown variable type of #{@variable['type']}"
                    end
                    ag = JSON.parse(argument_template.result(get_binding))
                  end
                  raise "Argument '#{@variable['name']}' did not process.  Most likely it did not have all parameters defined." if ag.nil?
                  wf['arguments'] << ag
                else # must be a variable
                  vr = nil
                  if @variable['method'] == 'static'
                    # add this as an argument
                    vr = JSON.parse(static_variable_template.result(get_binding))
                  elsif @variable['method'] == 'lhs'
                    if @variable['type'] == 'enum'
                      @values_and_weights = @variable['distribution']['enumerations'].map { |v| {value: v} }.to_json
                      vr =JSON.parse(discrete_uncertain_variable_template.result(get_binding))
                    else
                      vr = JSON.parse(uncertain_variable_template.result(get_binding))
                    end
                  elsif @variable['method'] == 'pivot'
                    @values_and_weights = @variable['distribution']['enumerations'].map { |v| {value: v} }.to_json
                    vr =JSON.parse(pivot_variable_template.result(get_binding))
                  end
                  raise "variable was nil after processing" if vr.nil?
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
          zipfile_name = "#{@export_path}/#{model[:name]}.zip"
          FileUtils.rm_f(zipfile_name) if File.exists?(zipfile_name)

          Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
            @weather_files.each do |filename|
              puts "  Adding #{filename}"
              zipfile.add("./weather/#{File.basename(filename)}", filename)
            end

            Dir.glob("#{@measure_path}/**/*.rb").each do |measure|
              next if measure.include?("spec") # don't include the spec folders nor files
              measure_name = measure.split(File::SEPARATOR).last(2).first
              puts "  Adding ./measures/#{measure_name}/#{File.basename(measure)}"
              zipfile.add("./measures/#{measure_name}/#{File.basename(measure)}", measure)
            end

            puts "Adding #{model[:path]}"
            zipfile.add("./seed/#{File.basename(model[:path])}", model[:path])

            puts "Adding in other files #{@other_files.inspect}"
            @other_files.each do |others|
              Dir[File.join(others[:path], '**', '**')].each do |file|
                zipfile.add(file.sub(others[:path], "./lib/#{others[:lib_zip_name]}/"), file)
              end
            end
          end
        end

        def create_analysis_json(analysis_json, model)
          # Set the seed model in the analysis_json
          analysis_json['analysis']['seed']['file_type'] = model[:type]
          # This is the path that will be seen on the server when this runs
          analysis_json['analysis']['seed']['path'] = "./seed/#{File.basename(model[:path])}"

          # Set the weather file as the first in the list -- this is optional
          # TODO: check if epw or if zip file

          analysis_json['analysis']['weather_file']['file_type'] = 'EPW'
          if File.extname(@weather_files.first) =~ /.zip/i
            analysis_json['analysis']['weather_file']['path'] = "./weather/#{File.basename(@weather_files.first, '.zip')}.epw"
          else
            analysis_json['analysis']['weather_file']['path'] = "./weather/#{File.basename(@weather_files.first)}"
          end

          json_file_name = "#{@export_path}/#{model[:name]}.json"
          FileUtils.rm_f(json_file_name) if File.exists?(json_file_name)

          File.open("#{@export_path}/#{model[:name]}.json", "w") { |f| f << JSON.pretty_generate(analysis_json) }
        end
        
        # parse_setup will pull out the data on the "setup" tab and store it in memory for later use
        def parse_setup()
          rows = @xls.sheet('Setup').parse()
          b_run_setup = false
          b_problem_setup = false
          b_weather_files = false
          b_models = false
          b_other_libs = false

          rows.each do |row|
            if row[0] == "Running Setup"
              b_run_setup = true
              b_problem_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = false
              next
            elsif row[0] == "Problem Definition"
              b_run_setup = false
              b_problem_setup = true
              b_weather_files = false
              b_models = false
              b_other_libs = false
              next
            elsif row[0] == "Weather Files"
              b_run_setup = false
              b_problem_setup = false
              b_weather_files = true
              b_models = false
              b_other_libs = false
              next
            elsif row[0] == "Models"
              b_run_setup = false
              b_problem_setup = false
              b_weather_files = false
              b_models = true
              b_other_libs = false
              next
            elsif row[0] == "Other Library Files"
              b_run_setup = false
              b_problem_setup = false
              b_weather_files = false
              b_models = false
              b_other_libs = true
              next
            end

            next if row[0].nil?

            if b_run_setup
              @name = row[1].chomp if row[0] == "Analysis Name"
              @export_path = File.expand_path(File.join(@root_path, row[1])) if row[0] == "Export Directory"
              @measure_path = File.expand_path(File.join(@root_path, row[1])) if row[0] == "Measure Directory"
            elsif b_problem_setup
              @number_of_samples = row[1].to_i if row[0] == "Number of Samples"
            elsif b_weather_files
              if row[0] == "Weather File"
                @weather_files += Dir.glob(File.expand_path(File.join(@root_path, row[1])))
              end
            elsif b_models
              @models << {name: row[1], type: row[2], path: File.expand_path(File.join(@root_path, row[3]))}
            elsif b_other_libs
              @other_files << {lib_zip_name: row[1], path: row[2]}
            end
          end
        end


        # parse_variables will parse the XLS spreadsheet and save the data into
        # a higher level JSON file.  The JSON file is historic and it should really 
        # be omitted as an intermediate step
        def parse_variables()
          rows = @xls.sheet('Variables').parse()
          
          if !rows 
            raise "Could not find the sheet name 'Variables' in excel file #{@root_path}"
          end
          
          data = {}
          data['data'] = []

          icnt = 0
          measure_index = -1
          variable_index = -1
          measure_name = nil
          rows.each do |row|
            icnt += 1
            # puts "Parsing line: #{icnt}"
            next if icnt <= 3 # skip the first 3 lines of the file

            # check if we are a measure
            if row[0].nil?
              unless measure_name.nil?
                variable_index += 1

                var = {}
                var['variable_type'] = row[1]
                var['display_name'] = row[2].strip
                var['machine_name'] = var['display_name'].downcase.strip.gsub("-", "_").gsub(" ", "_").strip
                var['name'] = row[3].strip
                var['index'] = variable_index #order of the variable (eventually use to force order of applying measures)

                var['method'] = row[4]
                var['type'] = row[5]
                var['units'] = row[6]

                var['distribution'] = {}

                #parse the enums
                if var['type'] == 'enum'
                  var['distribution']['enumerations'] = row[8].gsub("|", "").split(",").map { |v| v.strip }
                elsif var['type'] == 'bool' #TODO: i think this has been deprecated
                  var['distribution']['enumerations'] = []
                  var['distribution']['enumerations'] << 'true'
                  var['distribution']['enumerations'] << 'false'
                end

                if var['method'] == 'lhs'
                  var['distribution']['min'] = row[9]
                  var['distribution']['max'] = row[10]
                  var['distribution']['mean'] = row[11]
                  var['distribution']['stddev'] = row[12]
                  var['distribution']['type'] = row[13]
                  var['distribution']['source'] = row[14]
                elsif var['method'] == 'static'
                  var['distribution']['static_value'] = row[7]
                  var['distribution']['source'] = row[14]
                end

                var['notes'] = row[15]
                var['relation_to_eui'] = row[16]

                data['data'][measure_index]['variables'] << var
              end
            else
              measure_index += 1
              variable_index = 0
              data['data'][measure_index] = {}

              #generate name id
              puts "Parsing measure #{row[1]}"
              display_name = row[1].chomp.strip
              measure_name = display_name.downcase.strip.gsub("-", "_").gsub(" ", "_")
              data['data'][measure_index]['display_name'] = display_name
              data['data'][measure_index]['name'] = measure_name
              data['data'][measure_index]['enabled'] = row[0] == "TRUE" ? true : false
              data['data'][measure_index]['measure_file_name'] = row[2]
              data['data'][measure_index]['measure_file_name_directory'] = row[2].underscore
              data['data'][measure_index]['measure_type'] = row[3]
              
              data['data'][measure_index]['version'] = @version_id

              data['data'][measure_index]['variables'] = []

            end
          end

          data
        end

      end
    end
  end
end
