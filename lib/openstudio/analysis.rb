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

    #Retrieve aws instance options from a project. This will return a hash
    def self.aws_instance_options(filename)
      if File.extname(filename) == ".xlsx"
        excel = OpenStudio::Analysis::Translator::Excel.new(filename)
        excel.process
        options = {
          :os_server_version => excel.settings['openstudio_server_version'],
          :server_instance_type => excel.settings['server_instance_type'],
          :worker_instance_type => excel.settings['worker_instance_type'],
          :worker_node_number => excel.settings['worker_nodes'].to_i,
          :user_id => excel.settings['user_id'],
          :aws_tags => excel.aws_tags,
          :analysis_type => excel.analyses.first.analysis_type,
          :cluster_name => excel.cluster_name
        }
      elsif File.extname(filename) == ".csv"
        csv = OpenStudio::Analysis::Translator::Datapoints.new(filename)
        csv.process
        options = csv.settings
      else
        fail 'Invalid file extension'
      end
      
      return options

    end
  end
end
