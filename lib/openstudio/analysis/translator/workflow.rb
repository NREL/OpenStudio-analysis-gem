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
            fail "File #{@osa_filename} does not exist"
          end

          # Initialize some other instance variables
          @osw_version = '0.0.1'
          @options = options
          @file_paths = options[:file_paths] ? options[:file_paths] : []
          @measure_paths = options[:measure_paths] ? options[:measure_paths] : []

          # Initialize static inputs from the OSA
          @seed_file = File.basename @osa[:seed][:path]
          @weather_file = File.basename @osa[:weather_file][:path]
          @osa_id = @osa[:_id]
          @steps = []
          @osa[:problem][:workflow].each_with_index do |step, i|
            step_hash = {}
            step_hash[:measure_dir_name] = File.basename(step[:measure_definition_directory])
            step_hash[:arguments] = {}
            # Measures can have no arguments -- make sure to catch it
            if @osa[:problem][:workflow][i][:arguments]
              @osa[:problem][:workflow][i][:arguments].each do |arg|
                step_hash[:arguments][arg[:name].to_sym] = arg[:value]
              end
            end
            step_hash[:name] = step[:name] if step[:name]
            step_hash[:measure_id] = step[:uuid] if step[:uuid]
            step_hash[:version_id] = step[:version_uuid] if step[:version_uuid]
            step_hash[:description] = step[:description] if step[:description]
            step_hash[:taxonomy] = step[:taxonomy] if step[:taxonomy]
            step_hash[:measure_type] = step[:measure_type]
            step_hash[:measure_type] = 'ModelMeasure' if step_hash[:measure_type] == 'RubyMeasure'
            @steps << step_hash
          end
        end

        # Convert a file in the form of an OSD into an OSW
        def process_datapoint(osd_filename)
          # Try to read the osd json file
          osd = nil
          if File.exist?(osd_filename)
            # warn('data_point selector in ods will be changed to datapoint in version 1.0') # NL this isn't true anymore.
            osd = ::JSON.parse(File.read(osd_filename), symbolize_names: true)[:data_point]
          else
            fail "File #{osd_filename} does not exist"
          end

          # Parse the osd hash based off of the osa hash. First check that the analysis id matches
          fail "File #{osd_filename} does not reference #{@osa_id}." unless @osa_id == osd[:analysis_id]
          # @todo (rhorsey) Fix the spec so this line can be uncommented
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

          # Save the OSW hash
          osw = {}
          created_at = ::Time.now
          osw[:seed_file] = @seed_file
          osw[:weather_file] = @weather_file
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
          return osw
        end

        # Runs an array of OSD files
        def process_datapoints(osd_filename_array)
          r = []
          osd_filename_array.each do |osd_file|
            begin
              r << process_datapoint(osd_file)
            rescue => e
              r << nil
              puts "Warning: Failed to process datapoint #{osd_file} with error #{e.message} in #{e.backtrace.join('\n')}"
            end
          end

          return r
        end
      end
    end
  end
end
