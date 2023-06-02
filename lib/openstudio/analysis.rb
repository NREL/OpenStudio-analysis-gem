# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# OpenStudio::Analysis Module instantiates versions of formulations
module OpenStudio
  module Analysis
    # Create a new analysis
    def self.create(display_name)
      OpenStudio::Analysis::Formulation.new(display_name)
    end

    # Load the analysis json or from a file. If this is a json then it must have
    # symbolized keys
    def self.load(h)
      h = MultiJson.load(h, symbolize_keys: true) unless h.is_a? Hash
      OpenStudio::Analysis::Formulation.from_hash h
    end

    # Load an analysis from excel. This will create an array of analyses because
    # excel can create more than one analyses
    def self.from_excel(filename)
      excel = OpenStudio::Analysis::Translator::Excel.new(filename)
      excel.process
      excel.analyses
    end

    # Load an set of batch datapoints from a csv. This will create a analysis
    # of type 'batch_datapoints' which requires 'batch_run'
    def self.from_csv(filename)
      csv = OpenStudio::Analysis::Translator::Datapoints.new(filename)
      csv.process
      csv.analysis
    end

    # Process an OSA with a set of OSDs into OSWs
    def self.make_osws(osa_filename, osd_array)
      translator = OpenStudio::Analysis::Translator::Workflow.new(osa_filename)
      osd_array.each { |osd| translator.process_datapoints osd }
    end

    # Retrieve aws instance options from a project. This will return a hash
    def self.aws_instance_options(filename)
      if File.extname(filename) == '.xlsx'
        excel = OpenStudio::Analysis::Translator::Excel.new(filename)
        excel.process
        options = {
          os_server_version: excel.settings['openstudio_server_version'],
          server_instance_type: excel.settings['server_instance_type'],
          worker_instance_type: excel.settings['worker_instance_type'],
          worker_node_number: excel.settings['worker_nodes'].to_i,
          user_id: excel.settings['user_id'],
          aws_tags: excel.aws_tags,
          analysis_type: excel.analyses.first.analysis_type,
          cluster_name: excel.cluster_name
        }
      elsif File.extname(filename) == '.csv'
        csv = OpenStudio::Analysis::Translator::Datapoints.new(filename)
        csv.process
        options = csv.settings
      else
        raise 'Invalid file extension'
      end

      return options
    end

    # Generate a DEnCity complient hash for uploading from the analysis hash
    # TODO make this work off of the analysis object, not the hash.
    def self.to_dencity_analysis(analysis_hash, analysis_uuid)
      dencity_hash = {}
      a = analysis_hash[:analysis]
      provenance = {}
      provenance[:user_defined_id] = analysis_uuid
      provenance[:user_created_date] = ::Time.now
      provenance[:analysis_types] = [a[:problem][:analysis_type]]
      provenance[:name] = a[:name]
      provenance[:display_name] = a[:display_name]
      provenance[:description] = 'Auto-generated DEnCity analysis hash using the OpenStudio Analysis Gem'
      measure_metadata = []
      if a[:problem]
        if a[:problem][:algorithm]
          provenance[:analysis_information] = a[:problem][:algorithm]
        else
          raise 'No algorithm found in the analysis.json.'
        end

        if a[:problem][:workflow]
          a[:problem][:workflow].each do |wf|
            new_wfi = {}
            new_wfi[:id] = wf[:measure_definition_uuid]
            new_wfi[:version_id] = wf[:measure_definition_version_uuid]

            # Eventually all of this could be pulled directly from BCL
            new_wfi[:name] = wf[:measure_definition_class_name] if wf[:measure_definition_class_name]
            new_wfi[:display_name] = wf[:measure_definition_display_name] if wf[:measure_definition_display_name]
            new_wfi[:type] = wf[:measure_type] if wf[:measure_type]
            new_wfi[:modeler_description] = wf[:modeler_description] if wf[:modeler_description]
            new_wfi[:description] = wf[:description] if wf[:description]
            new_wfi[:arguments] = []

            wf[:arguments]&.each do |arg|
              wfi_arg = {}
              wfi_arg[:display_name] = arg[:display_name] if arg[:display_name]
              wfi_arg[:display_name_short] = arg[:display_name_short] if arg[:display_name_short]
              wfi_arg[:name] = arg[:name] if arg[:name]
              wfi_arg[:data_type] = arg[:value_type] if arg[:value_type]
              wfi_arg[:default_value] = nil
              wfi_arg[:description] = ''
              wfi_arg[:display_units] = '' # should be haystack compatible unit strings
              wfi_arg[:units] = '' # should be haystack compatible unit strings

              new_wfi[:arguments] << wfi_arg
            end

            wf[:variables]&.each do |arg|
              wfi_var = {}
              wfi_var[:display_name] = arg[:argument][:display_name] if arg[:argument][:display_name]
              wfi_var[:display_name_short] = arg[:argument][:display_name_short] if arg[:argument][:display_name_short]
              wfi_var[:name] = arg[:argument][:name] if arg[:argument][:name]
              wfi_var[:default_value] = nil
              wfi_var[:data_type] = arg[:argument][:value_type] if arg[:argument][:value_type]
              wfi_var[:description] = ''
              wfi_var[:display_units] = arg[:units] if arg[:units]
              wfi_var[:units] = '' # should be haystack compatible unit strings
              new_wfi[:arguments] << wfi_var
            end

            measure_metadata << new_wfi
          end
        else
          raise 'No workflow found in the analysis.json'
        end

        dencity_hash[:analysis] = provenance
        dencity_hash[:measure_definitions] = measure_metadata
      else
        raise 'No problem found in the analysis.json'
      end
      return dencity_hash
    end
  end
end
