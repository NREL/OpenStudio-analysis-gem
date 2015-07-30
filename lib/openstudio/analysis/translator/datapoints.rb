module OpenStudio
  module Analysis
    module Translator
      class Datapoints
        attr_reader :version
        attr_reader :settings
        attr_reader :variables
        attr_reader :outputs
        attr_reader :models
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
        attr_reader :analysis_name

        # Methods to override instance variables

        # Pass in the filename to read
        def initialize(csv_filename)
          @csv_filename = csv_filename
          @root_path = File.expand_path(File.dirname(@csv_filename))

          @csv = nil
          # Try to read the spreadsheet as a roo object
          if File.exist?(@csv_filename)
            @csv = CSV.read(@csv_filename)
          else
            fail "File #{@csv_filename} does not exist"
          end

          # Remove nil rows and check row length
          @csv.delete_if {|row| row.uniq.length == 1 && row.uniq[0].nil?}


          # Initialize some other instance variables
          @version = '0.0.1'
          @analyses = [] # Array o OpenStudio::Analysis. Use method to access
          @name = nil
          @analysis_name = nil
          @cluster_name = nil
          @settings = {}
          @weather_paths = []
          @models = []
          @other_files = []
          @worker_inits = []
          @worker_finals = []
          @export_path = './export'
          @measure_paths = []
          @problem = {}
          @algorithm = {}
          @outputs = {}
          @run_setup = {}
          @aws_tags = []
        end

        def process
          @setup = parse_csv

          @version = Semantic::Version.new @version
          fail "Csv interface version #{@version} is no longer supported.  Please upgrade your csv interface to at least 0.0.1" if @version < '0.0.0'

          @variables = parse_rows

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
            fail "Measures directory '#{mp}' does not exist" unless Dir.exist?(mp)
          end

          @models.uniq!
          fail 'No seed models defined in spreadsheet' if @models.empty?

          @models.each do |model|
            fail "Seed model does not exist: #{model[:path]}" unless File.exist?(model[:path])
          end

          @weather_paths.uniq!
          fail 'No weather files found based on what is in the spreadsheet' if @weather_paths.empty?

          @weather_paths.each do |wf|
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
          measure_display_names = @variables.map{|m| m[:measure_data][:display_name]}.compact
          measure_display_names_mult = measure_display_names.select { |m| measure_display_names.count(m) > 1 }.uniq
          if measure_display_names_mult && !measure_display_names_mult.empty?
            fail "Measure Display Names are not unique for '#{measure_display_names_mult.join('\', \'')}'"
          end

          variable_names = @variables.map{|v| v[:vars].map{|hash| hash[:display_name]}}.flatten
          dupes = variable_names.select { |e| variable_names.count(e) > 1 }.uniq
          if dupes.count > 0
            fail "duplicate variable names found in list #{dupes.inspect}"
          end

        end

        # convert the data in excel's parsed data into an OpenStudio Analysis Object
        # @seed_model [Hash] Seed model to set the new analysis to
        # @append_model_name [Boolean] Append the name of the seed model to the display name
        # @return [Object] An OpenStudio::Analysis
        def analysis(seed_model = nil, append_model_name = false)
          fail 'There are no seed models defined in the excel file. Please add one.' if @models.size == 0
          fail 'There are more than one seed models defined in the excel file. This is not supported by the CSV Translator.' if @models.size > 1 && seed_model.nil?

          seed_model = @models.first if seed_model.nil?

          # Use the programmatic interface to make the analysis
          # append the model name to the analysis name if requested (normally if there are more than 1 models in the spreadsheet)
          display_name = append_model_name ? @name + ' ' + seed_model[:display_name] : @name

          a = OpenStudio::Analysis.create(display_name)

          @variables.each do |measure|
            @measure_paths.each do |measure_path|
              measure_dir_to_add = "#{measure_path}/#{measure[:measure_data][:classname]}"
              if Dir.exist? measure_dir_to_add
                if File.exist? "#{measure_dir_to_add}/measure.rb"
                  measure[:measure_data][:local_path_to_measure] = "#{measure_dir_to_add}/measure.rb"
                  break
                else
                  fail "Measure in directory '#{measure_dir_to_add}' did not contain a measure.rb file"
                end
              end
            end

            fail "Could not find measure '#{measure['name']}' in directory named '#{measure['measure_file_name_directory']}' in the measure paths '#{@measure_paths.join(', ')}'" unless measure[:measure_data][:local_path_to_measure]

            a.workflow.add_measure_from_csv(measure)
          end

          @other_files.each do |library|
            a.libraries.add(library[:path], library_name: library[:lib_zip_name])
          end

          @worker_inits.each do |w|
            a.worker_inits.add(w[:path],  args: w[:args])
          end

          @worker_finals.each do |w|
            a.worker_finalizes.add(w[:path], args: w[:args])
          end

          # Add in the outputs
          @outputs.each do |o|
            o = Hash[o.map { |k, v| [k.to_sym, v] }]
            a.add_output(o)
          end

          a.analysis_type = @problem['analysis_type']

          # clear out the seed files before adding new ones
          a.seed_model = seed_model[:path]

          # clear out the weather files before adding new ones
          a.weather_files.clear
          @weather_paths.each do |wp|
            a.weather_files.add_files(wp)
          end

          a

        end

        protected

        def parse_csv
          # Check that the configuration row is conferable to a hash
          config_row = @csv[0]
          config_row.select!{|elem| !elem.nil?}
          fail "Wrong number of key value pairs in configuration line of #{filename}" if config_row.length%2 != 0

          # Convert to hash
          config_hash = {}
          for i in 0..(config_row.length/2 - 1)
            config_hash[config_row[i*2].to_sym] = config_row[i*2 + 1]
          end

          # Assign required attributes
          fail 'Require setting not found: version' unless config_hash[:version]
          @version = config_hash[:version]
          
          if config_hash[:analysis_name]
            @name = config_hash[:analysis_name]
          else
            @name = SecureRandom.uuid
          end
          @analysis_name = @name.snake_case

          fail 'Require setting not found: measure_path' unless config_hash[:measure_paths]
          config_hash[:measure_paths] = [config_hash[:measure_paths]] unless config_hash[:measure_paths].respond_to?(:each)
          config_hash[:measure_paths].each do |path|
            if (Pathname.new path).absolute?
              @measure_paths << path
            else
              @measure_paths << File.expand_path(File.join(@root_path, path))
            end
          end

          fail 'Required setting not found: weather_paths' unless config_hash[:weather_paths]
          config_hash[:weather_paths] = [config_hash[:weather_paths]] unless config_hash[:weather_paths].respond_to?(:each)
          config_hash[:weather_paths].each do |path|
            if (Pathname.new path).absolute?
              @weather_paths << path
            else
              @weather_paths << File.expand_path(File.join(@root_path, path))
            end
          end

          fail 'Required setting not found: models' unless config_hash[:models]
          config_hash[:models] = [config_hash[:models]] unless config_hash[:models].respond_to?(:each)
          config_hash[:models].each do |path|
            model_name = File.basename(path).split('.')[0]
            model_name = SecureRandom.uuid if model_name == ''
            type = File.basename(path).split('.')[1].upcase
            unless(Pathname.new path).absolute?
              path = File.expand_path(File.join(@root_path, path))
            end
            @models << {name: model_name.snake_case, display_name: model_name, type: type, path: path}
          end

          # Assign optional attributes
          if config_hash[:output]
            if File.exists? config_hash[:output].to_s
              @outputs = MultiJson.load(File.read(config_hash[:output].to_s))
            else
              fail "Could not find output json: #{config_hash[:output]}"
            end
          end

          if config_hash[:export_path]
            if(Pathname.new config_hash[:export_path]).absolute?
              @export_path = config_hash[:export_path]
            else
              @export_path = File.expand_path(File.join(@root_path, config_hash[:export_path]))
            end
          end

          if config_hash[:library_path]
            library_name = File.basename(config_hash).split('.')[0]
            unless (Pathname.new config_hash[:library_path]).absolute?
              config_hash[:library_path] = File.expand_path(File.join(@root_path, config_hash[:library_path]))
            end
            @other_files << {lib_zip_name: library_name, path: config_hash[:library_path]}
          end

          @run_setup['allow_multiple_jobs'] = config_hash[:allow_multiple_jobs].to_s.to_bool if config_hash[:allow_multiple_jobs]
          @run_setup['use_server_as_worker'] = config_hash[:use_server_as_worker].to_s.to_bool if config_hash[:use_server_as_worker]

          # Assign AWS settings
          @settings['proxy_port'] = config_hash[:proxy_port] if config_hash[:proxy_port]
          @settings['cluster_name'] = config_hash[:cluster_name] if config_hash[:cluster_name]
          @settings['user_id'] = config_hash[:user_id] if config_hash[:user_id]
          @settings['os_server_version'] = config_hash[:os_server_version] if config_hash[:os_server_version]
          @settings['server_instance_type'] = config_hash[:server_instance_type] if config_hash[:server_instance_type]
          @settings['worker_instance_type'] = config_hash[:worker_instance_type] if config_hash[:worker_instance_type]
          @settings['worker_node_number'] = config_hash[:worker_node_number].to_i if config_hash[:worker_node_number]
          @settings['aws_tags'] = config_hash[:aws_tags] if config_hash[:aws_tags]
          @settings['analysis_type'] = 'batch_datapoints'
        end

        def parse_rows
          # Build metadata required for parsing
          measures = @csv[1].uniq.select{|measure| !measure.nil?}.map{|measure| measure.to_sym}
          measure_map = {}
          measure_var_list = []
          measures.each do |measure|
            measure_map[measure] = {}
            col_ind = (0..(@csv[1].length-1)).to_a.select{|i| @csv[1][i] == measure.to_s}
            col_ind.each do |var_ind|
              tuple = measure.to_s + @csv[2][var_ind]
              fail "Multiple measure_variable tuples found for '#{measure.to_s}_#{@csv[2][var_ind]}'. These tuples must be unique." if measure_var_list.include? tuple
              measure_var_list << tuple
              measure_map[measure][@csv[2][var_ind].to_sym] = var_ind
            end
          end

          # For each measure load measure json and parse out critical variable requirements
          data = []
          measures.each_with_index do |measure, measure_index|
            data[measure_index] = {}
            measure_json = ''
            for i in 0..(@measure_paths.length-1)
              if File.exists? File.join(@measure_paths[i],measure.to_s,'measure.json')
                measure_json = MultiJson.load(File.read(File.join(@measure_paths[i],measure.to_s,'measure.json')))
                break
              end
            end
            fail "Could not find measure json #{measure.to_s}.json in measure_paths: '#{@measure_paths.join("\n")}'" if measure_json == ''
            measure_data = {}
            measure_data[:classname] = measure_json['classname']
            measure_data[:name] = measure_json['name']
            measure_data[:display_name] = measure_json['display_name']
            measure_data[:measure_type] = measure_json['measure_type']
            measure_data[:uid] = measure_json['uid']
            measure_data[:version_id] = measure_json['version_id']
            data[measure_index][:measure_data] = measure_data
            data[measure_index][:vars] = []
            vars = measure_map[measure]
            vars.each do |var|
              var = var[0]
              var_hash = {}
              var_json = measure_json['arguments'].select{|hash| hash['local_variable'] == var.to_s}[0]
              var_hash[:variable_type] = var_json['variable_type']
              var_hash[:display_name] = @csv[3][measure_map[measure][var]]
              var_hash[:display_name_short] = var_hash[:display_name]
              var_hash[:name] = var_json['local_variable']
              var_hash[:type] = var_json['variable_type'].downcase
              var_hash[:units] = var_json['units']
              var_hash[:distribution] = {}
              case var_hash[:type]
                when 'bool', 'boolean' # is 'boolean' necessary? it's not in the enum catch
                  var_hash[:distribution][:values] = (4..(@csv.length-1)).map{|value| @csv[value.to_i][measure_map[measure][var]].to_s == 'true'}
                  var_hash[:distribution][:maximum] = true
                  var_hash[:distribution][:minimum] = false
                  var_hash[:distribution][:mode] = var_hash[:distribution][:values].group_by{|i| i}.max{|x,y| x[1].length <=> y[1].length}[0]
                when 'choice'
                  var_hash[:distribution][:values] = (4..(@csv.length)-1).map{|value| @csv[value.to_i][measure_map[measure][var]].to_s}
                  var_hash[:distribution][:minimum] = var_hash[:distribution][:values].min
                  var_hash[:distribution][:maximum] = var_hash[:distribution][:values].max
                  var_hash[:distribution][:mode] = var_hash[:distribution][:values].group_by{|i| i}.max{|x,y| x[1].length <=> y[1].length}[0]
                else
                  var_hash[:distribution][:values] = (4..(@csv.length-1)).map{|value| eval(@csv[value.to_i][measure_map[measure][var]])}
                  var_hash[:distribution][:minimum] = var_hash[:distribution][:values].map{|value| value.to_i}.min
                  var_hash[:distribution][:maximum] = var_hash[:distribution][:values].map{|value| value.to_i}.max
                  var_hash[:distribution][:mode] = var_hash[:distribution][:values].group_by{|i| i}.max{|x,y| x[1].length <=> y[1].length}[0]
              end
              var_hash[:distribution][:weights] = eval('[' + "#{1.0/(@csv.length-4)}," * (@csv.length-4) + ']')
              var_hash[:distribution][:type] = 'discrete'
              var_hash[:distribution][:units] = var_hash[:units]
              if var_hash[:type] == 'choice'
                var_hash[:distribution][:enumerations] = var_json['choices']
              elsif var_hash[:type] == 'bool'
                var_hash[:distribution][:enumerations] = []
                var_hash[:distribution][:enumerations] << 'true' # TODO: should this be a real bool?
                var_hash[:distribution][:enumerations] << 'false'
              end
              data[measure_index][:vars] << var_hash
            end
            data[measure_index][:args] = []
            measure_json['arguments'].each do |arg_json|
              arg = {}
              arg[:value_type] = arg_json['variable_type'],
              arg[:name] = arg_json['name'],
              arg[:display_name] = arg_json['display_name'],
              arg[:display_name_short] = arg_json['display_name'],
              arg[:default_value] = arg_json['default_value'],
              arg[:value] = arg_json['default_value']
              data[measure_index][:args] << arg
            end          
          end

          data

        end
      end
    end
  end
end