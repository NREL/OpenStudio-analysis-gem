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

      # the attributes below are used for packaging data into the analysis zip file
      attr_reader :weather_files
      attr_reader :seed_models
      attr_reader :worker_inits
      attr_reader :worker_finalizes
      attr_reader :libraries

      # Create an instance of the OpenStudio::Analysis::Formulation
      #
      # @param display_name [String] Display name of the project.
      # @return [Object] An OpenStudio::Analysis::Formulation object
      def initialize(display_name)
        @display_name = display_name
        @analysis_type = nil
        @outputs = []

        # Initialize child objects (expect workflow)
        @weather_file = WeatherFile.new
        @seed_model = SeedModel.new
        @algorithm = OpenStudio::Analysis::AlgorithmAttributes.new

        # Analysis Zip attributes
        @weather_files = SupportFiles.new
        @seed_models = SupportFiles.new
        @worker_inits = SupportFiles.new
        @worker_finalizes = SupportFiles.new
        @libraries = SupportFiles.new
        # @initialization_scripts = SupportFiles.new
      end

      # Initialize or return the current workflow object
      #
      # @return [Object] An OpenStudio::Analysis::Workflow object
      def workflow
        @workflow ||= OpenStudio::Analysis::Workflow.new
      end

      # Define the type of analysis which is going to be running
      #
      # @param name [String] Name of the algorithm/analysis. (e.g. rgenoud, lhs, single_run)
      attr_writer :analysis_type

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
        output_hash = {
          units: '',
          objective_function: false,
          objective_function_index: nil,
          objective_function_target: nil,
          objective_function_group: nil,
          scaling_factor: nil
        }.merge(output_hash)

        # Check if the name is already been added. Note that if the name is added again, it will not update any of
        # the fields
        exist = @outputs.select { |o| o[:name] == output_hash[:name] }
        if exist.empty?
          # if the variable is an objective_function, then increment and
          # assign and objective function index
          if output_hash[:objective_function]
            values = @outputs.select { |o| o[:objective_function] }
            output_hash[:objective_function_index] = values.size # size is already +1
          else
            output_hash[:objective_function] = false
          end

          @outputs << output_hash
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
          elsif @weather_files.size > 0
            # get the first EPW file (not the first file)
            wf = @weather_files.find { |w| File.extname(w[:file]).downcase == '.epw' }
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

      private

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
            zf.add(f[:file].sub(f[:file], "./lib/worker_initialize/#{ordered_file_name}"), f[:file])

            if f[:metadata][:args]
              arg_file = "#{File.basename(ordered_file_name, '.*')}.args"
              file = Tempfile.new('arg')
              file.write(f[:metadata][:args])
              zf.add("./lib/worker_initialize/#{arg_file}", file)
              file.close
            end
          end

          puts 'Adding Support Files: Worker Finalization Scripts'
          @worker_finalizes.each_with_index do |f, index|
            ordered_file_name = "#{index.to_s.rjust(2, '0')}_#{File.basename(f[:file])}"
            puts "  Adding #{f[:file]} as #{ordered_file_name}"
            zf.add(f[:file].sub(f[:file], "./lib/worker_finalize/#{ordered_file_name}"), f[:file])

            if f[:metadata][:args]
              arg_file = "#{File.basename(ordered_file_name, '.*')}.args"
              file = Tempfile.new('arg')
              file.write(f[:metadata][:args])
              zf.add("./lib/worker_finalize/#{arg_file}", file)
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
