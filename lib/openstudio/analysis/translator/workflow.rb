module OpenStudio
  module Analysis
    module Translator

      require 'json'
      require 'securerandom'

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

          @analysis = nil
          # try to read the osa json file
          if File.exist?(@osa_filename)
            @osa = ::JSON.loads(File.read(@osa_filename), {symbolize_keys: true})[:analysis]
          else
            fail "File #{@osa_filename} does not exist"
          end

          # Initialize some other instance variables
          @osw_version = '0.0.1'
          @options = options
          @file_paths = options[:file_paths] ? options[:file_paths] : []
          @measure_paths = options[:measure_paths] ? options[:measure_paths] : []

          # Initialize static inputs from the OSA
          @seed_file = @osa[:seed][:path]
          @weather_file = @osa[:weather_file][:path]
          @osa_id = @osa_filename.gsub('analysis','').gsub('_','')
          @steps = []
          @osa[:workflow].each do |step|
            step_hash = {}
            step_hash[:measure_dir_name] = File.basename(step['measure_definition_directory'])
            step_hash[:arguments] = []
            step_hash[:arguments].each do |arg|
              arg_hash = {
                  name: arg[:name],
                  value: arg[:value]
              }
              step_hash[:arguments] << arg_hash
            end
            @steps << step_hash
          end
        end

        def process_datapoint(osd_filename)
          # Try to read the osd json file
          if File.exist?(osd_filename)
            osd = ::JSON.loads(File.read(osd_filename), {symbolize_keys: true})[:data_point]
          else
            fail "File #{@osa_filename} does not exist"
          end

          # Parse the osd hash based off of the osa hash. First check that the analysis id matches
          fail "File #{osd_filename} does not reference #{@osa_id}." unless @osa_id == osd[:analysis_id]
          osd_id = osd[:id]
          osw_steps_instance = @steps
          osw_steps_instance.each do |step|
            step[:variables].each do |var|
              var_name = var[:argument][:name]
              var_value_uuid = var[:uuid]
              var_value = osd[:set_variable_values][var_value_uuid.to_sym]
              var_hash = {
                  name: var_name,
                  value: var_value
              }
              step[:arguments] << var_hash
            end
          end

          # Save the OSW hash
          osw = {}
          osw_id = SecureRandom.uuid
          osw_filename = "./datapoints/workflow_#{osw_id}.json"
          created_at = ::Time.now
          osw[:seed_model] = @seed_file
          osw[:weather_file] = @weather_file
          osw[:file_format_version] = @osw_version
          osw[:osa_id] = @osa_id
          osw[:osd_id] = @osa_id
          osw[:created_at] = created_at
          osw[:id] = osw_id
          osw[:measure_paths] = @measure_paths
          osw[:file_paths] = @file_paths
          osw[:run_directory] = './..'
          osw[:steps] = osw_steps_instance
          File.open(osw_filename, 'wb').each {|f| f << ::JSON.pretty_generate(osw)}
        end

        # Runs an array of OSD files
        def process_datapoints(osd_filename_array)
          osd_filename_array.each do |osd_file|
            begin
              process_datapoint(osd_file)
            rescue => e
              puts "Warning: Failed to processes datapoint #{osd_file} with error #{e.message} in #{e.backtrace.join('\n')}"
            end
          end
        end
      end
    end
  end
end
