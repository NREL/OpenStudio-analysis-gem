# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# OpenStudio formulation class handles the generation of the OpenStudio Analysis format.
module OpenStudio
  module Analysis
    SeedModel = Struct.new(:file)
    WeatherFile = Struct.new(:file)

    @@measure_paths = ['./measures']
    # List of paths to look for measures when adding them. This currently only is used when loading an
    # analysis hash file. It looks in the order of the measure_paths. As soon as it finds one, it stops.
    def self.measure_paths
      @@measure_paths
    end

    def self.measure_paths=(new_array)
      @@measure_paths = new_array
    end

    class Formulation
      attr_reader :seed_model
      attr_reader :weather_file
      attr_reader :analysis_type
      attr_reader :outputs
      attr_accessor :display_name
      attr_accessor :workflow
      attr_accessor :algorithm
      attr_accessor :osw_path
      attr_accessor :download_zip

      # the attributes below are used for packaging data into the analysis zip file
      attr_reader :weather_files
      attr_reader :seed_models
      attr_reader :worker_inits
      attr_reader :worker_finalizes
      attr_reader :libraries
      attr_reader :server_scripts

      # Create an instance of the OpenStudio::Analysis::Formulation
      #
      # @param display_name [String] Display name of the project.
      # @return [Object] An OpenStudio::Analysis::Formulation object
      def initialize(display_name)
        @display_name = display_name
        @analysis_type = nil
        @outputs = []
        @workflow = OpenStudio::Analysis::Workflow.new
        # Initialize child objects (expect workflow)
        @weather_file = WeatherFile.new
        @seed_model = SeedModel.new
        @algorithm = OpenStudio::Analysis::AlgorithmAttributes.new
        @download_zip = true

        # Analysis Zip attributes
        @weather_files = SupportFiles.new
        @seed_models = SupportFiles.new
        @worker_inits = SupportFiles.new
        @worker_finalizes = SupportFiles.new
        @libraries = SupportFiles.new
        @server_scripts = ServerScripts.new
      end
     
      # Define the type of analysis which is going to be running
      #
      # @param name [String] Name of the algorithm/analysis. (e.g. rgenoud, lhs, single_run)
      # allowed values are ANALYSIS_TYPES = ['spea_nrel', 'rgenoud', 'nsga_nrel', 'lhs', 'preflight', 
      #                                      'morris', 'sobol', 'doe', 'fast99', 'ga', 'gaisl', 
      #                                      'single_run', 'repeat_run', 'batch_run']
      def analysis_type=(value)
        if OpenStudio::Analysis::AlgorithmAttributes::ANALYSIS_TYPES.include?(value)
          @analysis_type = value
        else
          raise "Invalid analysis type. Allowed types: #{OpenStudio::Analysis::AlgorithmAttributes::ANALYSIS_TYPES}"
        end
      end

      # Path to the seed model
      #
      # @param path [String] Path to the seed model. This should be relative.
      def seed_model=(file)
        @seed_model[:file] = file
      end

      # Path to the weather file (or folder). If it is a folder, then the measures will look for the weather file
      # by name in that folder.
      #
      # @param path [String] Path to the weather file or folder.
      def weather_file=(file)
        @weather_file[:file] = file
      end

      # Set the value for 'download_zip'
      #
      # @param value [Boolean] The value for 'download_zip'
      def download_zip=(value)
        if [true, false].include?(value)
          @download_zip = value
        else
          raise ArgumentError, "Invalid value for 'download_zip'. Only true or false allowed."
        end
      end
  
      # Add an output of interest to the problem formulation
      #
      # @param output_hash [Hash] Hash of the output variable in the legacy format
      # @option output_hash [String] :display_name Name to display
      # @option output_hash [String] :display_name_short A shorter display name
      # @option output_hash [String] :metadata_id Link to DEnCity ID in which this output corresponds
      # @option output_hash [String] :name Unique machine name of the variable. Typically this is measure.attribute
      # @option output_hash [String] :export Export the variable to CSV and dataframes from OpenStudio-server
      # @option output_hash [String] :visualize Visualize the variable in the plots on OpenStudio-server
      # @option output_hash [String] :units Units of the variable as a string
      # @option output_hash [String] :variable_type Data type of the variable
      # @option output_hash [Boolean] :objective_function Whether or not this output is an objective function. Default: false
      # @option output_hash [Integer] :objective_function_index Index of the objective function. Default: nil
      # @option output_hash [Float] :objective_function_target Target for the objective function to reach (if defined). Default: nil
      # @option output_hash [Float] :scaling_factor How to scale the objective function(s). Default: nil
      # @option output_hash [Integer] :objective_function_group If grouping objective functions, then group ID. Default: nil
      def add_output(output_hash)
        # Check if the name is already been added.
        exist = @outputs.find_index { |o| o[:name] == output_hash[:name] }
        # if so, update the fields but keep objective_function_index the same
        if exist
          original = @outputs[exist]
          if original[:objective_function] && !output_hash[:objective_function]
            return @outputs
          end
          output = original.merge(output_hash)
          output[:objective_function_index] = original[:objective_function_index]
          @outputs[exist] = output
        else
          output = {
            units: '',
            objective_function: false,
            objective_function_index: nil,
            objective_function_target: nil,
            #set default to nil or 1 if objective_function is true and this is not set
            objective_function_group: (output_hash[:objective_function] ? 1 : nil),
            scaling_factor: nil,
            #set default to false or true if objective_function is true and this is not set
            visualize: (output_hash[:objective_function] ? true : false),
            metadata_id: nil,
            export: true,
          }.merge(output_hash)
          #set display_name default to be name if its not set
          output[:display_name] = output_hash[:display_name] ? output_hash[:display_name] : output_hash[:name]
          #set display_name_short default to be display_name if its not set, this can be null if :display_name not set
          output[:display_name_short] = output_hash[:display_name_short] ? output_hash[:display_name_short] : output_hash[:display_name]
          # if the variable is an objective_function, then increment and
          # assign and objective function index
          if output[:objective_function]
            values = @outputs.select { |o| o[:objective_function] }
            output[:objective_function_index] = values.size
          end

          @outputs << output
        end

        @outputs
      end

      # return the machine name of the analysis
      def name
        @display_name.to_underscore
      end

      # return a hash.
      #
      # @param version [Integer] Version of the format to return
      # @return [Hash]
      def to_hash(version = 1)
        # fail 'Must define an analysis type' unless @analysis_type
        if version == 1
          h = {
            analysis: {
              display_name: @display_name,
              name: name,
              output_variables: @outputs,
              problem: {
                analysis_type: @analysis_type,
                algorithm: algorithm.to_hash(version),
                workflow: workflow.to_hash(version)
              }
            }
          }

          if @seed_model[:file]
            h[:analysis][:seed] = {
              file_type: File.extname(@seed_model[:file]).delete('.').upcase,
              path: "./seed/#{File.basename(@seed_model[:file])}"
            }
          else
            h[:analysis][:seed] = nil
          end

          # silly catch for if weather_file is not set
          wf = nil
          if @weather_file[:file]
            wf = @weather_file
          elsif !@weather_files.empty?
            # get the first EPW file (not the first file)
            wf = @weather_files.find { |w| File.extname(w[:file]).casecmp('.epw').zero? }
          end

          if wf
            h[:analysis][:weather_file] = {
              file_type: File.extname(wf[:file]).delete('.').upcase,
              path: "./weather/#{File.basename(wf[:file])}"
            }
          else
            # log: could not find weather file
            warn 'Could not resolve a valid weather file. Check paths to weather files'
          end

          h[:analysis][:file_format_version] = version
          h[:analysis][:cli_debug] = "--debug"
          h[:analysis][:cli_verbose] = "--verbose"
          h[:analysis][:run_workflow_timeout] = 28800
          h[:analysis][:upload_results_timeout] = 28800
          h[:analysis][:initialize_worker_timeout] = 28800
          h[:analysis][:download_zip] = @download_zip
          #-BLB I dont think this does anything. server_scripts are run if they are in 
          #the /scripts/analysis or /scripts/data_point directories
          #but nothing is ever checked in the OSA.
          #
          h[:analysis][:server_scripts] = {}

          # This is a hack right now, but after the initial hash is created go back and add in the objective functions
          # to the the algorithm as defined in the output_variables list
          ofs = @outputs.map { |i| i[:name] if i[:objective_function] }.compact
          if h[:analysis][:problem][:algorithm]
            h[:analysis][:problem][:algorithm][:objective_functions] = ofs
          end

          h
        else
          raise "Version #{version} not defined for #{self.class} and #{__method__}"
        end
      end

      # Load the analysis JSON from a hash (with symbolized keys)
      def self.from_hash(h, seed_dir = nil, weather_dir = nil)
        o = OpenStudio::Analysis::Formulation.new(h[:analysis][:display_name])

        version = 1
        if version == 1
          h[:analysis][:output_variables].each do |ov|
            o.add_output(ov)
          end

          o.workflow = OpenStudio::Analysis::Workflow.load(workflow: h[:analysis][:problem][:workflow])

          if weather_dir
            o.weather_file "#{weather_path}/#{File.basename(h[:analysis][:weather_file][:path])}"
          else
            o.weather_file = h[:analysis][:weather_file][:path]
          end

          if seed_dir
            o.seed_model "#{weather_path}/#{File.basename(h[:analysis][:seed][:path])}"
          else
            o.seed_model = h[:analysis][:seed][:path]
          end
        else
          raise "Version #{version} not defined for #{self.class} and #{__method__}"
        end

        o
      end

      # return a hash of the data point with the static variables set
      #
      # @param version [Integer] Version of the format to return
      # @return [Hash]
      def to_static_data_point_hash(version = 1)
        if version == 1
          static_hash = {}
          # TODO: this method should be on the workflow step and bubbled up to this interface
          @workflow.items.map do |item|
            item.variables.map { |v| static_hash[v[:uuid]] = v[:static_value] }
          end

          h = {
            data_point: {
              set_variable_values: static_hash,
              status: 'na',
              uuid: SecureRandom.uuid
            }
          }
          h
        end
      end

      # save the file to JSON. Will overwrite the file if it already exists
      #
      # @param filename [String] Name of file to create. It will create the directory and override the file if it exists. If no file extension is given, then it will use .json.
      # @param version [Integer] Version of the format to return
      # @return [Boolean]
      def save(filename, version = 1)
        filename += '.json' if File.extname(filename) == ''

        FileUtils.mkdir_p File.dirname(filename) unless Dir.exist? File.dirname(filename)
        File.open(filename, 'w') { |f| f << JSON.pretty_generate(to_hash(version)) }

        true
      end

      # save the data point JSON with the variables set to the static values. Will overwrite the file if it already exists
      #
      # @param filename [String] Name of file to create. It will create the directory and override the file if it exists. If no file extension is given, then it will use .json.
      # @param version [Integer] Version of the format to return
      # @return [Boolean]
      def save_static_data_point(filename, version = 1)
        filename += '.json' if File.extname(filename) == ''

        FileUtils.mkdir_p File.dirname(filename) unless Dir.exist? File.dirname(filename)
        File.open(filename, 'w') { |f| f << JSON.pretty_generate(to_static_data_point_hash(version)) }

        true
      end

      # save the analysis zip file which contains the measures, seed model, weather file, and init/final scripts
      #
      # @param filename [String] Name of file to create. It will create the directory and override the file if it exists. If no file extension is given, then it will use .json.
      # @return [Boolean]
      def save_zip(filename)
        filename += '.zip' if File.extname(filename) == ''

        FileUtils.mkdir_p File.dirname(filename) unless Dir.exist? File.dirname(filename)

        save_analysis_zip(filename)
      end
      
      
      def save_osa_zip(filename, all_weather_files = false, all_seed_files = false)
        filename += '.zip' if File.extname(filename) == ''

        FileUtils.mkdir_p File.dirname(filename) unless Dir.exist? File.dirname(filename)

        save_analysis_zip_osa(filename, all_weather_files, all_seed_files)
      end
      
      # convert an OSW to an OSA
      # osw_filename is the full path to the OSW file
      # assumes the associated files and directories are in the same location
      #  /example.osw
      #  /measures
      #  /seeds
      #  /weather
      #
      def convert_osw(osw_filename, *measure_paths)
        # load OSW so we can loop over [:steps]
        if File.exist? osw_filename  #will this work for both rel and abs paths?
          osw = JSON.parse(File.read(osw_filename), symbolize_names: true)
          @osw_path = File.expand_path(osw_filename)
        else
          raise "Could not find workflow file #{osw_filename}"
        end
        
        # set the weather and seed files if set in OSW
        # use :file_paths and look for files to set
        if osw[:file_paths]        
          # seed_model, check if in OSW and not found in path search already
          if osw[:seed_file]
            osw[:file_paths].each do |path|
              puts "searching for seed at: #{File.join(File.expand_path(path), osw[:seed_file])}"
              if File.exist?(File.join(File.expand_path(path), osw[:seed_file]))
                puts "found seed_file: #{osw[:seed_file]}"
                self.seed_model = File.join(File.expand_path(path), osw[:seed_file])
                break
              end
            end  
          else 
            warn "osw[:seed_file] is not defined"            
          end

          # weather_file, check if in OSW and not found in path search already
          if osw[:weather_file]
            osw[:file_paths].each do |path|
              puts "searching for weather at: #{File.join(File.expand_path(path), osw[:weather_file])}"
              if File.exist?(File.join(File.expand_path(path), osw[:weather_file]))
                puts "found weather_file: #{osw[:weather_file]}"
                self.weather_file = File.join(File.expand_path(path), osw[:weather_file])
                break
              end 
            end
          else 
            warn "osw[:weather_file] is not defined"            
          end

        # file_paths is not defined in OSW, so warn and try to set 
        else
          warn ":file_paths is not defined in the OSW."
          self.weather_file = osw[:weather_file] ? osw[:weather_file] : nil
          self.seed_model = osw[:seed_file] ? osw[:seed_file] : nil
        end
        
        #set analysis_type default to Single_Run
        self.analysis_type = 'single_run'

        #loop over OSW 'steps' and map over measures
        #there is no name/display name in the OSW. Just measure directory name
        #read measure.XML from directory to get name / display name
        #increment name by +_1 if there are duplicates
        #add measure
        #change default args to osw arg values 
        
        osw[:steps].each do |step|
          #get measure directory
          measure_dir = step[:measure_dir_name]
          measure_name = measure_dir.split("measures/").last
          puts "measure_dir_name: #{measure_name}"
          #get XML
          # Loop over possible user defined *measure_paths, including the dir of the osw_filename path and :measure_paths, to find the measure, 
          # then set measure_dir_abs_path to that path
          measure_dir_abs_path = ''
          paths_to_parse = [File.dirname(osw_filename), osw[:measure_paths], *measure_paths].flatten.compact.map { |path| File.join(File.expand_path(path), measure_dir, 'measure.xml') }
          puts "searching for xml's in: #{paths_to_parse}"
          xml = {}
          paths_to_parse.each do |path|
            if File.exist?(path)
              puts "found xml: #{path}"
              xml = parse_measure_xml(path)
              if !xml.empty?
                measure_dir_abs_path = path
                break
              end
            end          
          end
          raise "measure #{measure_name} not found" if xml.empty?
          puts ""          
          #add check for previous names _+1
          count = 1
          name = xml[:name]
          display_name = xml[:display_name]
          loop do
            measure = @workflow.find_measure(name)
            break if measure.nil?

            count += 1
            name = "#{xml[:name]}_#{count}"
            display_name = "#{xml[:display_name]} #{count}"
          end   
          #Add Measure to workflow
          @workflow.add_measure_from_path(name, display_name, measure_dir_abs_path)  #this forces to an absolute path which seems constent with PAT
          #@workflow.add_measure_from_path(name, display_name, measure_dir)  #this uses the path in the OSW which could be relative          
          
          #Change the default argument values to the osw values
          #1. find measure in @workflow
          m = @workflow.find_measure(name)
          #2. loop thru osw args
          #check if the :argument is missing from the measure step, it shouldnt be but just in case give a clean message
          if step[:arguments].nil?
            raise "measure #{name} step has no arguments: #{step}"
          else          
            step[:arguments].each do |k,v|
              #check if argument is in measure, otherwise setting argument_value will crash
              raise "OSW arg: #{k} is not in Measure: #{name}" if m.arguments.find_all { |a| a[:name] == k.to_s }.empty?
              #set measure arg to match osw arg
              m.argument_value(k.to_s, v)
            end
          end
        end
      end

      private

      # New format for OSAs. Package up the seed, weather files, and measures
      # filename is the name of the file to be saved. ex: analysis.zip
      # it will parse the OSA and zip up all the files defined in the workflow
      def save_analysis_zip_osa(filename, all_weather_files = false, all_seed_files = false)
        def add_directory_to_zip_osa(zipfile, local_directory, relative_zip_directory)
          puts "Add Directory #{local_directory}"
          Dir[File.join(local_directory.to_s, '**', '**')].each do |file|
            puts "Adding File #{file}"
            zipfile.add(file.sub(local_directory, relative_zip_directory), file)
          end
          zipfile
        end
        #delete file if exists
        FileUtils.rm_f(filename) if File.exist?(filename)
        #get the full path to the OSW, since all Files/Dirs should be in same directory as the OSW
        puts "osw_path: #{@osw_path}"
        osw_full_path = File.dirname(File.expand_path(@osw_path))
        puts "osw_full_path: #{osw_full_path}"

        Zip::File.open(filename, create: true) do |zf|
         ## Weather files
          puts 'Adding Support Files: Weather'
          # check if weather file exists.  use abs path.  remove leading ./ from @weather_file path if there.
          # check if path is already absolute
          if @weather_file[:file]
            if File.exists?(@weather_file[:file])
              puts "  Adding #{@weather_file[:file]}"
              #zf.add("weather/#{File.basename(@weather_file[:file])}", @weather_file[:file])
              base_name = File.basename(@weather_file[:file], ".*")
              puts "base_name: #{base_name}"
              # convert backslash on windows to forward slash so Dir.glob will work (in case user uses \)
              weather_dirname = File.dirname(@weather_file[:file]).gsub("\\", "/")
              puts "weather_dirname: #{weather_dirname}"
              # If all_weather_files is true, add all files in the directory to the zip.
              # Otherwise, add only files that match the base name.
              file_pattern = all_weather_files ? "*" : "#{base_name}.*"
              Dir.glob(File.join(weather_dirname, file_pattern)) do |file_path|
               puts "file_path: #{file_path}"
               puts "zip path: weather/#{File.basename(file_path)}"
               zf.add("weather/#{File.basename(file_path)}", file_path)
            end
            # make absolute path and check for file  
            elsif File.exists?(File.join(osw_full_path,@weather_file[:file].sub(/^\.\//, '')))
              puts "  Adding: #{File.join(osw_full_path,@weather_file[:file].sub(/^\.\//, ''))}"
              #zf.add("weather/#{File.basename(@weather_file[:file])}", File.join(osw_full_path,@weather_file[:file].sub(/^\.\//, '')))
              base_name = File.basename(@weather_file[:file].sub(/^\.\//, ''), ".*")
              puts "base_name2: #{base_name}"
              weather_dirname = File.dirname(File.join(osw_full_path,@weather_file[:file].sub(/^\.\//, ''))).gsub("\\", "/")
              puts "weather_dirname: #{weather_dirname}"
              file_pattern = all_weather_files ? "*" : "#{base_name}.*"
              Dir.glob(File.join(weather_dirname, file_pattern)) do |file_path|
                puts "file_path2: #{file_path}"
                puts "zip path2: weather/#{File.basename(file_path)}"
                zf.add("weather/#{File.basename(file_path)}", file_path)
              end
            else
              raise "weather_file[:file] does not exist at: #{File.join(osw_full_path,@weather_file[:file].sub(/^\.\//, ''))}"
            end
          else
            warn "weather_file[:file] is not defined"
          end

          ## Seed files
          puts 'Adding Support Files: Seed Models'
          #check if seed file exists.  use abs path.  remove leading ./ from @seed_model path if there.
          #check if path is already absolute
          if @seed_model[:file]
            if File.exists?(@seed_model[:file])
              puts "  Adding #{@seed_model[:file]}"
              zf.add("seeds/#{File.basename(@seed_model[:file])}", @seed_model[:file])
              if all_seed_files
                seed_dirname = File.dirname(@seed_model[:file]).gsub("\\", "/")
                puts "seed_dirname: #{seed_dirname}"
                Dir.glob(File.join(seed_dirname, '*')) do |file_path|
                  next if file_path == @seed_model[:file] # Skip if the file is the same as @seed_model[:file] so not added twice
                  puts "file_path: #{file_path}"
                  puts "zip path: seeds/#{File.basename(file_path)}"
                  zf.add("seeds/#{File.basename(file_path)}", file_path)
                end              
              end
            #make absolute path and check for file  
            elsif File.exists?(File.join(osw_full_path,@seed_model[:file].sub(/^\.\//, '')))
              puts "  Adding #{File.join(osw_full_path,@seed_model[:file].sub(/^\.\//, ''))}"
              zf.add("seeds/#{File.basename(@seed_model[:file])}", File.join(osw_full_path,@seed_model[:file].sub(/^\.\//, '')))
              if all_seed_files
                seed_dirname = File.dirname(File.join(osw_full_path,@seed_model[:file].sub(/^\.\//, ''))).gsub("\\", "/")
                puts "seed_dirname: #{seed_dirname}"
                Dir.glob(File.join(seed_dirname, '*')) do |file_path|
                  next if file_path == File.join(osw_full_path,@seed_model[:file].sub(/^\.\//, '')) # Skip if the file is the same as @seed_model[:file] so not added twice
                  puts "file_path: #{file_path}"
                  puts "zip path: seeds/#{File.basename(file_path)}"
                  zf.add("seeds/#{File.basename(file_path)}", file_path)
                end              
              end
            else
              raise "seed_file[:file] does not exist at: #{File.join(osw_full_path,@seed_model[:file].sub(/^\.\//, ''))}"
            end        
          else
            warn "seed_file[:file] is not defined"
          end
          
          puts 'Adding Support Files: Libraries'
          @libraries.each do |lib|
            raise "Libraries must specify their 'library_name' as metadata which becomes the directory upon zip" unless lib[:metadata][:library_name]

            if File.directory? lib[:file]
              Dir[File.join(lib[:file], '**', '**')].each do |file|
                puts "  Adding #{file}"
                zf.add(file.sub(lib[:file], "lib/#{lib[:metadata][:library_name]}"), file)
              end
            else
              # just add the file to the zip
              puts "  Adding #{lib[:file]}"
              zf.add(lib[:file], "lib/#{File.basename(lib[:file])}", lib[:file])
            end
          end

          puts 'Adding Support Files: Server Scripts'
          @server_scripts.each_with_index do |f, index|
            if f[:init_or_final] == 'finalization'
              file_name = 'finalization.sh'
            else
              file_name = 'initialization.sh'
            end
            if f[:server_or_data_point] == 'analysis'
              new_name = "scripts/analysis/#{file_name}"
            else
              new_name = "scripts/data_point/#{file_name}"
            end
            puts "  Adding #{f[:file]} as #{new_name}"
            zf.add(new_name, f[:file])

            if f[:arguments]
              arg_file = "#{(new_name.sub(/\.sh\z/, ''))}.args"
              puts "  Adding arguments as #{arg_file}"
              file = Tempfile.new('arg')
              file.write(f[:arguments])
              zf.add(arg_file, file)
              file.close
            end
          end

          ## Measures
          puts 'Adding Measures'
          added_measures = []
          # The list of the measures should always be there, but make sure they are uniq
          @workflow.each do |measure|
            measure_dir_to_add = measure.measure_definition_directory_local

            next if added_measures.include? measure_dir_to_add

            puts "  Adding #{File.basename(measure_dir_to_add)}"
            Dir[File.join(measure_dir_to_add, '**')].each do |file|
              if File.directory?(file)
                if File.basename(file) == 'resources' || File.basename(file) == 'lib'
                  #remove leading ./ from measure_definition_directory path if there.
                  add_directory_to_zip_osa(zf, file, "#{measure.measure_definition_directory.sub(/^\.\//, '')}/#{File.basename(file)}")
                end
              else
                puts "    Adding File #{file}"
                #remove leading ./ from measure.measure_definition_directory string with regex .sub(/^\.\//, '')
                zip_path_for_measures = file.sub(measure_dir_to_add, measure.measure_definition_directory.sub(/^\.\//, ''))
                #puts "    zip_path_for_measures: #{zip_path_for_measures}"
                zf.add(zip_path_for_measures, file)
              end
            end

            added_measures << measure_dir_to_add
          end
        end
      end
      
      #keep legacy function
      # Package up the seed, weather files, and measures
      def save_analysis_zip(filename)
        def add_directory_to_zip(zipfile, local_directory, relative_zip_directory)
          # puts "Add Directory #{local_directory}"
          Dir[File.join(local_directory.to_s, '**', '**')].each do |file|
            # puts "Adding File #{file}"
            zipfile.add(file.sub(local_directory, relative_zip_directory), file)
          end
          zipfile
        end

        FileUtils.rm_f(filename) if File.exist?(filename)

        Zip::File.open(filename, Zip::File::CREATE) do |zf|
          ## Weather files
          # TODO: eventually remove the @weather_file attribute and grab the weather file out
          # of the @weather_files
          puts 'Adding Support Files: Weather'
          if @weather_file[:file] && !@weather_files.files.find { |f| @weather_file[:file] == f[:file] }
            # manually add the weather file
            puts "  Adding #{@weather_file[:file]}"
            zf.add("./weather/#{File.basename(@weather_file[:file])}", @weather_file[:file])
          end
          @weather_files.each do |f|
            puts "  Adding #{f[:file]}"
            zf.add("./weather/#{File.basename(f[:file])}", f[:file])
          end

          ## Seed files
          puts 'Adding Support Files: Seed Models'
          if @seed_model[:file] && !@seed_models.files.find { |f| @seed_model[:file] == f[:file] }
            # manually add the weather file
            puts "  Adding #{@seed_model[:file]}"
            zf.add("./seed/#{File.basename(@seed_model[:file])}", @seed_model[:file])
          end
          @seed_models.each do |f|
            puts "  Adding #{f[:file]}"
            zf.add("./seed/#{File.basename(f[:file])}", f[:file])
          end

          puts 'Adding Support Files: Libraries'
          @libraries.each do |lib|
            raise "Libraries must specify their 'library_name' as metadata which becomes the directory upon zip" unless lib[:metadata][:library_name]

            if File.directory? lib[:file]
              Dir[File.join(lib[:file], '**', '**')].each do |file|
                puts "  Adding #{file}"
                zf.add(file.sub(lib[:file], "./lib/#{lib[:metadata][:library_name]}/"), file)
              end
            else
              # just add the file to the zip
              puts "  Adding #{lib[:file]}"
              zf.add(lib[:file], "./lib/#{File.basename(lib[:file])}", lib[:file])
            end
          end

          puts 'Adding Support Files: Worker Initialization Scripts'
          @worker_inits.each_with_index do |f, index|
            ordered_file_name = "#{index.to_s.rjust(2, '0')}_#{File.basename(f[:file])}"
            puts "  Adding #{f[:file]} as #{ordered_file_name}"
            zf.add(f[:file].sub(f[:file], "./scripts/worker_initialization//#{ordered_file_name}"), f[:file])

            if f[:metadata][:args]
              arg_file = "#{File.basename(ordered_file_name, '.*')}.args"
              file = Tempfile.new('arg')
              file.write(f[:metadata][:args])
              zf.add("./scripts/worker_initialization/#{arg_file}", file)
              file.close
            end
          end

          puts 'Adding Support Files: Worker Finalization Scripts'
          @worker_finalizes.each_with_index do |f, index|
            ordered_file_name = "#{index.to_s.rjust(2, '0')}_#{File.basename(f[:file])}"
            puts "  Adding #{f[:file]} as #{ordered_file_name}"
            zf.add(f[:file].sub(f[:file], "scripts/worker_finalization/#{ordered_file_name}"), f[:file])

            if f[:metadata][:args]
              arg_file = "#{File.basename(ordered_file_name, '.*')}.args"
              file = Tempfile.new('arg')
              file.write(f[:metadata][:args])
              zf.add("scripts/worker_finalization/#{arg_file}", file)
              file.close
            end
          end
          
          ## Measures
          puts 'Adding Measures'
          added_measures = []
          # The list of the measures should always be there, but make sure they are uniq
          @workflow.each do |measure|
            measure_dir_to_add = measure.measure_definition_directory_local

            next if added_measures.include? measure_dir_to_add

            puts "  Adding #{File.basename(measure_dir_to_add)}"
            Dir[File.join(measure_dir_to_add, '**')].each do |file|
              if File.directory?(file)
                if File.basename(file) == 'resources' || File.basename(file) == 'lib'
                  add_directory_to_zip(zf, file, "#{measure.measure_definition_directory}/#{File.basename(file)}")
                end
              else
                # puts "Adding File #{file}"
                zf.add(file.sub(measure_dir_to_add, "#{measure.measure_definition_directory}/"), file)
              end
            end

            added_measures << measure_dir_to_add
          end
        end
      end
    end
  end
end
