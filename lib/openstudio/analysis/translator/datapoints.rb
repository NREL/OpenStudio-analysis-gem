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

        require 'nokogiri'

        # Pass in the filename to read
        def initialize(csv_filename)
          @csv_filename = csv_filename
          @root_path = File.expand_path(File.dirname(@csv_filename))

          @csv = nil
          # Try to read the spreadsheet as a roo object
          if File.exist?(@csv_filename)
            @csv = CSV.read(@csv_filename)
          else
            raise "File #{@csv_filename} does not exist"
          end

          # Remove nil rows and check row length
          @csv.delete_if { |row| row.uniq.length == 1 && row.uniq[0].nil? }

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
          # Seperate CSV into meta and measure groups
          measure_tag_index = nil
          @csv.each_with_index { |row, index| measure_tag_index = index if row[0] == 'BEGIN-MEASURES' }
          raise "ERROR: No 'BEGIN-MEASURES' tag found in input csv file." unless measure_tag_index
          meta_rows = []
          measure_rows = []
          @csv.each_with_index do |_, index|
            meta_rows << @csv[index] if index < measure_tag_index
            measure_rows << @csv[index] if index > measure_tag_index
          end

          @setup = parse_csv_meta(meta_rows)

          @version = Semantic::Version.new @version
          raise "CSV interface version #{@version} is no longer supported.  Please upgrade your csv interface to at least 0.0.1" if @version < '0.0.0'

          @variables = parse_csv_measures(measure_rows)

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

          @weather_paths.uniq!
          raise 'No weather files found based on what is in the spreadsheet' if @weather_paths.empty?

          @weather_paths.each do |wf|
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
          measure_display_names = @variables.map { |m| m[:measure_data][:display_name] }.compact
          measure_display_names_mult = measure_display_names.select { |m| measure_display_names.count(m) > 1 }.uniq
          if measure_display_names_mult && !measure_display_names_mult.empty?
            raise "Measure Display Names are not unique for '#{measure_display_names_mult.join('\', \'')}'"
          end

          variable_names = @variables.map { |v| v[:vars].map { |hash| hash[:display_name] } }.flatten
          dupes = variable_names.select { |e| variable_names.count(e) > 1 }.uniq
          if dupes.count > 0
            raise "duplicate variable names found in list #{dupes.inspect}"
          end
        end

        # convert the data in excel's parsed data into an OpenStudio Analysis Object
        # @seed_model [Hash] Seed model to set the new analysis to
        # @append_model_name [Boolean] Append the name of the seed model to the display name
        # @return [Object] An OpenStudio::Analysis
        def analysis(seed_model = nil, append_model_name = false)
          raise 'There are no seed models defined in the excel file. Please add one.' if @models.size == 0
          raise 'There are more than one seed models defined in the excel file. This is not supported by the CSV Translator.' if @models.size > 1 && seed_model.nil?

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
                  raise "Measure in directory '#{measure_dir_to_add}' did not contain a measure.rb file"
                end
              end
            end

            raise "Could not find measure '#{measure['name']}' in directory named '#{measure['measure_file_name_directory']}' in the measure paths '#{@measure_paths.join(', ')}'" unless measure[:measure_data][:local_path_to_measure]

            a.workflow.add_measure_from_csv(measure)
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

        def parse_csv_meta(meta_rows)
          # Convert to hash
          config_hash = {}
          meta_rows.each do |row|
            config_hash[row[0].to_sym] = row[1]
          end

          # Assign required attributes
          raise 'Require setting not found: version' unless config_hash[:version]
          @version = config_hash[:version]

          if config_hash[:analysis_name]
            @name = config_hash[:analysis_name]
          else
            @name = SecureRandom.uuid
          end
          @analysis_name = @name.to_underscore

          raise 'Require setting not found: measure_path' unless config_hash[:measure_paths]
          config_hash[:measure_paths] = [config_hash[:measure_paths]] unless config_hash[:measure_paths].respond_to?(:each)
          config_hash[:measure_paths].each do |path|
            if (Pathname.new path).absolute?
              @measure_paths << path
            else
              @measure_paths << File.expand_path(File.join(@root_path, path))
            end
          end

          raise 'Required setting not found: weather_paths' unless config_hash[:weather_paths]
          config_hash[:weather_paths] = config_hash[:weather_paths].split(',')
          config_hash[:weather_paths].each do |path|
            if (Pathname.new path).absolute?
              @weather_paths << path
            else
              @weather_paths << File.expand_path(File.join(@root_path, path))
            end
          end

          raise 'Required setting not found: models' unless config_hash[:models]
          config_hash[:models] = [config_hash[:models]] unless config_hash[:models].respond_to?(:each)
          config_hash[:models].each do |path|
            model_name = File.basename(path).split('.')[0]
            model_name = SecureRandom.uuid if model_name == ''
            type = File.basename(path).split('.')[1].upcase
            unless (Pathname.new path).absolute?
              path = File.expand_path(File.join(@root_path, path))
            end
            @models << { name: model_name.to_underscore, display_name: model_name, type: type, path: path }
          end

          # Assign optional attributes
          if config_hash[:output_json]
            path = File.expand_path(File.join(@root_path, config_hash[:output_json].to_s))
            if File.exist? path
              @outputs = MultiJson.load(File.read(path))
            else
              raise "Could not find output json: #{config_hash[:output_json]}"
            end
          end

          if config_hash[:export_path]
            if (Pathname.new config_hash[:export_path]).absolute?
              @export_path = config_hash[:export_path]
            else
              @export_path = File.expand_path(File.join(@root_path, config_hash[:export_path]))
            end
          end

          if config_hash[:library_path]
            library_name = File.basename(config_hash[:library_path]).split('.')[0]
            unless (Pathname.new config_hash[:library_path]).absolute?
              config_hash[:library_path] = File.expand_path(File.join(@root_path, config_hash[:library_path]))
            end
            @other_files << { lib_zip_name: library_name, path: config_hash[:library_path] }
          end

          if config_hash[:allow_multiple_jobs]
            raise 'allow_multiple_jobs is no longer a valid option in the CSV, please delete and rerun'
          end
          if config_hash[:use_server_as_worker]
            raise 'use_server_as_worker is no longer a valid option in the CSV, please delete and rerun'
          end

          # Assign AWS settings
          @settings[:proxy_port] = config_hash[:proxy_port] if config_hash[:proxy_port]
          @settings[:cluster_name] = config_hash[:cluster_name] if config_hash[:cluster_name]
          @settings[:user_id] = config_hash[:user_id] if config_hash[:user_id]
          @settings[:os_server_version] = config_hash[:os_server_version] if config_hash[:os_server_version]
          @settings[:server_instance_type] = config_hash[:server_instance_type] if config_hash[:server_instance_type]
          @settings[:worker_instance_type] = config_hash[:worker_instance_type] if config_hash[:worker_instance_type]
          @settings[:worker_node_number] = config_hash[:worker_node_number].to_i if config_hash[:worker_node_number]
          @settings[:aws_tags] = config_hash[:aws_tags] if config_hash[:aws_tags]
          @settings[:analysis_type] = 'batch_datapoints'
        end

        def parse_csv_measures(measure_rows)
          # Build metadata required for parsing
          measures = measure_rows[0].uniq.select { |measure| !measure.nil? }.map(&:to_sym)
          measure_map = {}
          measure_var_list = []
          measures.each do |measure|
            measure_map[measure] = {}
            col_ind = (0..(measure_rows[0].length - 1)).to_a.select { |i| measure_rows[0][i] == measure.to_s }
            col_ind.each do |var_ind|
              tuple = measure.to_s + measure_rows[1][var_ind]
              raise "Multiple measure_variable tuples found for '#{measure}_#{measure_rows[1][var_ind]}'. These tuples must be unique." if measure_var_list.include? tuple
              measure_var_list << tuple
              measure_map[measure][measure_rows[1][var_ind].to_sym] = var_ind
            end
          end

          # For each measure load measure json and parse out critical variable requirements
          data = []
          measures.each_with_index do |measure, measure_index|
            data[measure_index] = {}
            measure_xml, measure_type = find_measure(measure.to_s)

            raise "Could not find measure #{measure} xml in measure_paths: '#{@measure_paths.join("\n")}'" unless measure_xml
            measure_data = {}
            measure_data[:classname] = measure_xml.xpath('/measure/class_name').text
            measure_data[:name] = measure_xml.xpath('/measure/name').text
            measure_data[:display_name] = measure_xml.xpath('/measure/display_name').text
            measure_data[:measure_type] = measure_type
            measure_data[:uid] = measure_xml.xpath('/measure/uid').text
            measure_data[:version_id] = measure_xml.xpath('/measure/version_id').text
            data[measure_index][:measure_data] = measure_data
            data[measure_index][:vars] = []
            vars = measure_map[measure]

            # construct the list of variables
            vars.each do |var|
              # var looks like [:cooling_adjustment, 0]
              var = var[0]
              next if var.to_s == 'None'
              var_hash = {}
              found_arg = nil
              measure_xml.xpath('/measure/arguments/argument').each do |arg|
                if var.to_s == '__SKIP__' || arg.xpath('name').text == var.to_s
                  found_arg = arg
                  break
                end
              end

              # var_json = measure_json['arguments'].select { |hash| hash['local_variable'] == var.to_s }[0]
              raise "measure.xml for measure #{measure} does not have an argument with argument == #{var}" unless found_arg
              var_type = nil
              var_units = ''
              if var.to_s == '__SKIP__'
                var_type = 'boolean'
                var_units = ''
              else
                var_type = found_arg.xpath('type').text.downcase
                var_units = found_arg.xpath('units')
              end

              var_hash[:name] = var.to_s
              var_hash[:variable_type] = 'variable'
              var_hash[:display_name] = measure_rows[2][measure_map[measure][var]]
              var_hash[:display_name_short] = var_hash[:display_name]
              # var_hash[:name] = var_json['local_variable']
              var_hash[:type] = var_type
              var_hash[:units] = var_units
              var_hash[:distribution] = {}
              case var_hash[:type].downcase
                when 'bool', 'boolean'
                  var_hash[:distribution][:values] = (3..(measure_rows.length - 1)).map { |value| measure_rows[value.to_i][measure_map[measure][var]].to_s.downcase == 'true' }
                  var_hash[:distribution][:maximum] = true
                  var_hash[:distribution][:minimum] = false
                  var_hash[:distribution][:mode] = var_hash[:distribution][:values].group_by { |i| i }.max { |x, y| x[1].length <=> y[1].length }[0]
                when 'choice', 'string'
                  var_hash[:distribution][:values] = (3..(measure_rows.length) - 1).map { |value| measure_rows[value.to_i][measure_map[measure][var]].to_s }
                  var_hash[:distribution][:minimum] = var_hash[:distribution][:values].min
                  var_hash[:distribution][:maximum] = var_hash[:distribution][:values].max
                  var_hash[:distribution][:mode] = var_hash[:distribution][:values].group_by { |i| i }.max { |x, y| x[1].length <=> y[1].length }[0]
                else
                  var_hash[:distribution][:values] = (3..(measure_rows.length - 1)).map { |value| eval(measure_rows[value.to_i][measure_map[measure][var]]) }
                  var_hash[:distribution][:minimum] = var_hash[:distribution][:values].map(&:to_i).min
                  var_hash[:distribution][:maximum] = var_hash[:distribution][:values].map(&:to_i).max
                  var_hash[:distribution][:mode] = var_hash[:distribution][:values].group_by { |i| i }.max { |x, y| x[1].length <=> y[1].length }[0]
              end
              var_hash[:distribution][:weights] = eval('[' + "#{1.0 / (measure_rows.length - 3)}," * (measure_rows.length - 3) + ']')
              var_hash[:distribution][:type] = 'discrete'
              var_hash[:distribution][:units] = var_hash[:units]
              if var_hash[:type] == 'choice'
                var_hash[:distribution][:enumerations] = found_arg.xpath('choices/choice').map { |s| s.xpath('value').text }
              elsif var_hash[:type] == 'bool'
                var_hash[:distribution][:enumerations] = []
                var_hash[:distribution][:enumerations] << true
                var_hash[:distribution][:enumerations] << false
              end
              data[measure_index][:vars] << var_hash
            end
            data[measure_index][:args] = []

            measure_xml.xpath('/measure/arguments/argument').each do |arg_xml|
              arg = {}
              arg[:value_type] = arg_xml.xpath('type').text.downcase
              arg[:name] = arg_xml.xpath('name').text.downcase
              arg[:display_name] = arg_xml.xpath('display_name').text.downcase
              arg[:display_name_short] = arg[:display_name]
              arg[:default_value] = arg_xml.xpath('default_value').text.downcase
              arg[:value] = arg[:default_value]
              data[measure_index][:args] << arg
            end
          end

          data
        end

        private

        # Find the measure in the measure path
        def find_measure(measure_name)
          @measure_paths.each do |mp|
            measure_xml = File.join(mp, measure_name, 'measure.xml')
            measure_rb = File.join(mp, measure_name, 'measure.rb')
            if File.exist?(measure_xml) && File.exist?(measure_rb)
              return Nokogiri::XML File.read(measure_xml), parse_measure_type(measure_rb)
            end
          end

          return nil, nil
        end

        def parse_measure_type(measure_filename)
          measure_string = File.read(measure_filename)

          if measure_string =~ /OpenStudio::Ruleset::WorkspaceUserScript/
            return 'EnergyPlusMeasure'
          elsif measure_string =~ /OpenStudio::Ruleset::ModelUserScript/
            return 'RubyMeasure'
          elsif measure_string =~ /OpenStudio::Ruleset::ReportingUserScript/
            return 'ReportingMeasure'
          elsif measure_string =~ /OpenStudio::Ruleset::UtilityUserScript/
            return 'UtilityUserScript'
          else
            raise "measure type is unknown with an inherited class in #{measure_filename}"
          end
        end
      end
    end
  end
end
