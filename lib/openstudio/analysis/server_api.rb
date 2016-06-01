# Class manages the communication with the server.
# Presently, this class is simple and stores all information in hashs
module OpenStudio
  module Analysis
    class ServerApi
      attr_reader :hostname

      # Define set of anlaysis methods require batch_run to be queued after them
      BATCH_RUN_METHODS = %w(lhs preflight single_run repeat_run doe diag baseline_perturbation batch_datapoints)

      def initialize(options = {})
        defaults = {hostname: 'http://localhost:8080'}
        options = defaults.merge(options)
        @logger = ::Logger.new('faraday.log')

        @hostname = options[:hostname]

        fail 'no host defined for server api class' if @hostname.nil?

        # TODO: add support for the proxy

        # create connection with basic capabilities
        @conn = Faraday.new(url: @hostname) do |faraday|
          faraday.request :url_encoded # form-encode POST params
          faraday.use Faraday::Response::Logger, @logger
          # faraday.response @logger # log requests to STDOUT
          faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
        end

        # create connection to server api with multipart capabilities
        @conn_multipart = Faraday.new(url: @hostname) do |faraday|
          faraday.request :multipart
          faraday.request :url_encoded # form-encode POST params
          faraday.use Faraday::Response::Logger, @logger
          # faraday.response :logger # log requests to STDOUT
          faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
        end
      end

      def get_projects
        response = @conn.get '/projects.json'

        projects_json = nil
        if response.status == 200
          projects_json = JSON.parse(response.body, symbolize_names: true, max_nesting: false)
        else
          fail 'did not receive a 200 in get_projects'
        end

        projects_json
      end

      def get_project_ids
        ids = get_projects
        ids.map { |project| project[:uuid] }
      end

      def delete_project(id)
        deleted = false
        response = @conn.delete "/projects/#{id}.json"
        if response.status == 204
          puts "Successfully deleted project #{id}"
          deleted = true
        else
          puts "ERROR deleting project #{id}"
          deleted = false
        end

        deleted
      end

      def delete_all
        ids = get_project_ids
        puts "deleting projects with IDs: #{ids}"
        success = true
        ids.each do |id|
          r = delete_project id
          success = false if r == false
        end

        success
      end

      def new_project(options = {})
        defaults = {project_name: "Project #{::Time.now.strftime('%Y-%m-%d %H:%M:%S')}"}
        options = defaults.merge(options)
        project_id = nil

        # TODO: make this a display name and a machine name
        project_hash = {project: {name: "#{options[:project_name]}"}}

        response = @conn.post do |req|
          req.url '/projects.json'
          req.headers['Content-Type'] = 'application/json'
          req.body = project_hash.to_json
        end

        if response.status == 201
          project_id = JSON.parse(response.body)['_id']

          puts "new project created with ID: #{project_id}"
          # grab the project id
        elsif response.status == 500
          puts '500 Error'
          puts response.inspect
        end

        project_id
      end

      def get_analyses(project_id)
        analysis_ids = []
        response = @conn.get "/projects/#{project_id}.json"
        if response.status == 200
          analyses = JSON.parse(response.body, symbolize_names: true, max_nesting: false)
          if analyses[:analyses]
            analyses[:analyses].each do |analysis|
              analysis_ids << analysis[:_id]
            end
          end
        end

        analysis_ids
      end

      def get_analyses_detailed(project_id)
        analyses = nil
        response = @conn.get "/projects/#{project_id}.json"
        if response.status == 200
          analyses = JSON.parse(response.body, symbolize_names: true, max_nesting: false)[:analyses]
        end

        analyses
      end

      # return the entire analysis JSON
      def get_analysis(analysis_id)
        result = nil
        response = @conn.get "/analyses/#{analysis_id}.json"
        if response.status == 200
          result = JSON.parse(response.body, symbolize_names: true, max_nesting: false)[:analysis]
        end

        result
      end

      # Check the status of the simulation. Format should be:
      # {
      #   analysis: {
      #     status: "completed",
      #     analysis_type: "batch_run"
      #   },
      #     data_points: [
      #     {
      #         _id: "bbd57e90-ce59-0131-35de-080027880ca6",
      #         status: "completed"
      #     }
      #   ]
      # }
      def get_analysis_status(analysis_id, analysis_type)
        status = nil

        # sleep 2  # super cheesy---need to update how this works. Right now there is a good chance to get a
        # race condition when the analysis state changes.
        unless analysis_id.nil?
          resp = @conn.get "analyses/#{analysis_id}/status.json"
          if resp.status == 200
            j = JSON.parse resp.body, symbolize_names: true
            if j && j[:analysis] && j[:analysis][:analysis_type] == analysis_type
              status = j[:analysis][:status]
            end
          end
        end

        status
      end

      # Check if the machine is alive
      #
      # return [Boolean] True if the machine has an awake value set
      def alive?
        m = machine_status

        m = !m[:status][:awake].nil? if m

        m
      end

      # Retrieve the machine status
      #
      # return [Hash]
      def machine_status
        status = nil

        begin
          resp = @conn.get do |req|
            req.url 'status.json'
            req.options.timeout = 10
            req.options.open_timeout = 10
          end

          if resp.status == 200
            j = JSON.parse resp.body, symbolize_names: true
            status = j if j
          end

        rescue Faraday::ConnectionFailed

        rescue Net::ReadTimeout

        end

        status
      end

      def get_analysis_status_and_json(analysis_id, analysis_type)
        status = nil
        j = nil

        # sleep 2  # super cheesy---need to update how this works. Right now there is a good chance to get a
        # race condition when the analysis state changes.
        unless analysis_id.nil?
          resp = @conn.get "analyses/#{analysis_id}/status.json"
          if resp.status == 200
            j = JSON.parse resp.body, symbolize_names: true
            if j && j[:analysis] && j[:analysis][:analysis_type] == analysis_type
              status = j[:analysis][:status]
            end
          end
        end

        [status, j]
      end

      # return the data point results in JSON format
      def get_analysis_results(analysis_id)
        analysis = nil

        response = @conn.get "/analyses/#{analysis_id}/analysis_data.json"
        if response.status == 200
          analysis = JSON.parse(response.body, symbolize_names: true, max_nesting: false)
        end

        analysis
      end

      def download_dataframe(analysis_id, format = 'rdata', save_directory = '.')
        downloaded = false
        file_path_and_name = nil

        response = @conn.get do |r|
          r.url "/analyses/#{analysis_id}/download_data.#{format}?export=true"
          r.options.timeout = 3600 # 60 minutes
        end
        if response.status == 200
          filename = response['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
          downloaded = true
          file_path_and_name = "#{save_directory}/#{filename}"
          puts "File #{filename} already exists, overwriting" if File.exist?(file_path_and_name)
          if format == 'rdata'
            File.open(file_path_and_name, 'wb') { |f| f << response.body }
          else
            File.open(file_path_and_name, 'w') { |f| f << response.body }
          end
        end

        [downloaded, file_path_and_name]
      end

      def download_variables(analysis_id, format = 'rdata', save_directory = '.')
        downloaded = false
        file_path_and_name = nil

        response = @conn.get "/analyses/#{analysis_id}/variables/download_variables.#{format}"
        if response.status == 200
          filename = response['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
          downloaded = true
          file_path_and_name = "#{save_directory}/#{filename}"
          puts "File #{filename} already exists, overwriting" if File.exist?(file_path_and_name)
          if format == 'rdata'
            File.open(file_path_and_name, 'wb') { |f| f << response.body }
          else
            File.open(file_path_and_name, 'w') { |f| f << response.body }
          end
        end

        [downloaded, file_path_and_name]
      end

      def download_datapoint(datapoint_id, save_directory = '.')
        downloaded = false
        file_path_and_name = nil

        response = @conn.get "/data_points/#{datapoint_id}/download"
        if response.status == 200
          filename = response['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
          downloaded = true
          file_path_and_name = "#{save_directory}/#{filename}"
          puts "File #{filename} already exists, overwriting" if File.exist?(file_path_and_name)
          File.open(file_path_and_name, 'wb') { |f| f << response.body }
        end

        [downloaded, file_path_and_name]
      end

      # Download a MongoDB Snapshot.  This database can get large.  For 13,000 simulations with
      # DEnCity reporting, the size is around 325MB
      def download_database(save_directory = '.')
        downloaded = false
        file_path_and_name = nil

        response = @conn.get do |r|
          r.url '/admin/backup_database?full_backup=true'
          r.options.timeout = 3600 # 60 minutes
        end

        if response.status == 200
          filename = response['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
          downloaded = true
          file_path_and_name = "#{save_directory}/#{filename}"
          puts "File #{filename} already exists, overwriting" if File.exist?(file_path_and_name)
          File.open(file_path_and_name, 'wb') { |f| f << response.body }
        end

        [downloaded, file_path_and_name]
      end

      def download_datapoint_reports(datapoint_id, save_directory = '.')
        downloaded = false
        file_path_and_name = nil

        response = @conn.get "/data_points/#{datapoint_id}/download_reports"
        if response.status == 200
          filename = response['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
          downloaded = true
          file_path_and_name = "#{save_directory}/#{filename}"
          puts "File #{filename} already exists, overwriting" if File.exist?(file_path_and_name)
          File.open(file_path_and_name, 'wb') { |f| f << response.body }
        end

        [downloaded, file_path_and_name]
      end

      def download_datapoints_reports(analysis_id, save_directory = '.')
        # get the list of all the datapoints
        dps = get_datapoint_status(analysis_id)
        dps.each do |dp|
          if dp[:status] == 'completed'
            download_datapoint_reports(dp[:_id], save_directory)
          end
        end
      end

      def download_datapoint_jsons(analysis_id, save_directory = '.')
        # get the list of all the datapoints
        dps = get_datapoint_status(analysis_id)
        dps.each do |dp|
          if dp[:status] == 'completed'
            dp_h = get_datapoint(dp[:_id])
            File.open("#{save_directory}/data_point_#{dp[:_id]}.json", 'w') { |f| f << JSON.pretty_generate(dp_h) }
          end
        end
      end

      def datapoint_dencity(datapoint_id)
        # Return the JSON (Full) of the datapoint
        data_point = nil

        resp = @conn.get "/data_points/#{datapoint_id}/dencity.json"
        if resp.status == 200
          data_point = JSON.parse resp.body, symbolize_names: true
        end

        data_point
      end

      def analysis_dencity_json(analysis_id)
        # Return the hash of the dencity format for the analysis
        dencity = nil

        resp = @conn.get "/analyses/#{analysis_id}/dencity.json"
        if resp.status == 200
          dencity = JSON.parse resp.body, symbolize_names: true
        end

        dencity
      end

      def download_dencity_json(analysis_id, save_directory = '.')
        a_h = analysis_dencity_json(analysis_id)
        if a_h
          File.open("#{save_directory}/analysis_#{analysis_id}_dencity.json", 'w') { |f| f << JSON.pretty_generate(a_h) }
        end
      end

      def download_datapoint_dencity_jsons(analysis_id, save_directory = '.')
        # get the list of all the datapoints
        dps = get_datapoint_status(analysis_id)
        dps.each do |dp|
          if dp[:status] == 'completed'
            dp_h = datapoint_dencity(dp[:_id])
            File.open("#{save_directory}/data_point_#{dp[:_id]}_dencity.json", 'w') { |f| f << JSON.pretty_generate(dp_h) }
          end
        end
      end

      def new_analysis(project_id, options)
        defaults = {
            analysis_name: nil,
            reset_uuids: false,
            push_to_dencity: false
        }
        options = defaults.merge(options)

        fail 'No project id passed' if project_id.nil?

        formulation_json = nil
        if options[:formulation_file]
          fail "No formulation exists #{options[:formulation_file]}" unless File.exist?(options[:formulation_file])
          formulation_json = JSON.parse(File.read(options[:formulation_file]), symbolize_names: true)
        end

        # read in the analysis id from the analysis.json file
        analysis_id = nil
        if formulation_json
          if options[:reset_uuids]
            analysis_id = SecureRandom.uuid
            formulation_json[:analysis][:uuid] = analysis_id

            formulation_json[:analysis][:problem][:workflow].each do |wf|
              wf[:uuid] = SecureRandom.uuid
              if wf[:arguments]
                wf[:arguments].each do |arg|
                  arg[:uuid] = SecureRandom.uuid
                end
              end
              if wf[:variables]
                wf[:variables].each do |var|
                  var[:uuid] = SecureRandom.uuid
                  var[:argument][:uuid] = SecureRandom.uuid if var[:argument]
                end
              end
            end
          else
            analysis_id = formulation_json[:analysis][:uuid]
          end

          # set the analysis name
          formulation_json[:analysis][:name] = "#{options[:analysis_name]}" unless options[:analysis_name].nil?
        else
          formulation_json = {
              analysis: options
          }
          puts formulation_json
          analysis_id = SecureRandom.uuid
          formulation_json[:analysis][:uuid] = analysis_id
        end
        fail "No analysis id defined in analysis.json #{options[:formulation_file]}" if analysis_id.nil?

        # save out this file to compare
        # File.open('formulation_merge.json', 'w') { |f| f << JSON.pretty_generate(formulation_json) }

        response = @conn.post do |req|
          req.url "projects/#{project_id}/analyses.json"
          req.headers['Content-Type'] = 'application/json'
          req.body = formulation_json.to_json
        end

        if response.status == 201
          puts "asked to create analysis with #{analysis_id}"
          # puts resp.inspect
          analysis_id = JSON.parse(response.body)['_id']
          puts "options[:push_to_dencity] = #{options[:push_to_dencity]}"
          upload_to_dencity(analysis_id, formulation_json) if options[:push_to_dencity]
          puts "new analysis created with ID: #{analysis_id}"
        else
          fail 'Could not create new analysis'
        end

        # check if we need to upload the analysis zip file
        if options[:upload_file]
          fail "upload file does not exist #{options[:upload_file]}" unless File.exist?(options[:upload_file])

          payload = {file: Faraday::UploadIO.new(options[:upload_file], 'application/zip')}
          response = @conn_multipart.post "analyses/#{analysis_id}/upload.json", payload do |req|
            req.options[:timeout] = 1800 # seconds
          end

          if response.status == 201
            puts 'Successfully uploaded ZIP file'
          else
            fail response.inspect
          end
        end

        analysis_id
      end

      def upload_to_dencity(analysis_uuid, analysis)
        require 'dencity'
        puts "Attempting to connect to DEnCity server using settings at '~/.dencity/config.yml'"
        conn = Dencity.connect
        fail "Could not connect to DEnCity server at #{hostname}." unless conn.connected?
        begin
          r = conn.login
        rescue Faraday::ParsingError => user_id_failure
          fail "Error in user_id field: #{user_id_failure.message}"
        rescue MultiJson::ParseError => authentication_failure
          fail "Error in attempted authentication: #{authentication_failure.message}"
        end
        user_uuid = r.id

        # Find the analysis.json file that SHOULD BE IN THE FOLDER THAT THIS SCRIPT IS IN (or change the below)
        # Check that the analysis has not yet been registered with the DEnCity instance.
        # TODO This should be simplified with a retrieve_analysis_by_user_defined_id' method in the future
        user_analyses = []
        r = conn.dencity_get 'analyses'
        runner.registerError('Unable to retrieve analyses from DEnCity server') unless r['status'] == 200
        r['data'].each do |dencity_analysis|
          user_analyses << dencity_analysis['id'] if dencity_analysis['user_id'] == user_uuid
        end
        found_analysis_uuid = false
        user_analyses.each do |dencity_analysis_id|
          dencity_analysis = conn.retrieve_analysis_by_id(dencity_analysis_id)
          if dencity_analysis['user_defined_id'] == analysis_uuid
            found_analysis_uuid = true
            break
          end
        end
        fail "Analysis with user_defined_id of #{analysis_uuid} found on DEnCity." if found_analysis_uuid
        dencity_hash = OpenStudio::Analysis.to_dencity_analysis(analysis, analysis_uuid)

        # Write the analysis DEnCity hash to dencity_analysis.json
        f = File.new('dencity_analysis.json', 'wb')
        f.write(JSON.pretty_generate(dencity_hash))
        f.close

        # Upload the processed analysis json.
        upload = conn.load_analysis 'dencity_analysis.json'
        begin
          upload_response = upload.push
        rescue => e
          runner.registerError("Upload failure: #{e.message} in #{e.backtrace.join('/n')}")
        else
          if NoMethodError == upload_response.class
            fail "ERROR: Server responded with a NoMethodError: #{upload_response}"
          end
          if upload_response.status.to_s[0] == '2'
            puts 'Successfully uploaded processed analysis json file to the DEnCity server.'
          else
            puts 'ERROR: Server returned a non-20x status. Response below.'
            puts upload_response
            fail
          end
        end
      end

      def upload_datapoint(analysis_id, options)
        defaults = {reset_uuids: false}
        options = defaults.merge(options)

        fail 'No analysis id passed' if analysis_id.nil?
        fail 'No datapoints file passed to new_analysis' unless options[:datapoint_file]
        fail "No datapoints_file exists #{options[:datapoint_file]}" unless File.exist?(options[:datapoint_file])

        dp_hash = JSON.parse(File.open(options[:datapoint_file]).read, symbolize_names: true)

        # There are two instances of the analysis ID. There is one in the file,
        # and the other is in the POST url. Ideally remove the version in the
        # file and support only the URL based analysis_id
        dp_hash[:analysis_uuid] = analysis_id

        if options[:reset_uuids]
          dp_hash[:uuid] = SecureRandom.uuid
        end

        # merge in the analysis_id as it has to be what is in the database
        response = @conn.post do |req|
          req.url "analyses/#{analysis_id}/data_points.json"
          req.headers['Content-Type'] = 'application/json'
          req.body = dp_hash.to_json
        end

        if response.status == 201
          puts "new datapoints created for analysis #{analysis_id}"
        else
          fail "could not create new datapoints #{response.body}"
        end
      end

      # Upload multiple data points to the server.
      def upload_datapoints(analysis_id, options)
        defaults = {}
        options = defaults.merge(options)

        fail 'No analysis id passed' if analysis_id.nil?
        fail 'No datapoints file passed to new_analysis' unless options[:datapoints_file]
        fail "No datapoints_file exists #{options[:datapoints_file]}" unless File.exist?(options[:datapoints_file])

        dp_hash = JSON.parse(File.open(options[:datapoints_file]).read, symbolize_names: true)

        # merge in the analysis_id as it has to be what is in the database
        response = @conn.post do |req|
          req.url "analyses/#{analysis_id}/data_points/batch_upload.json"
          req.headers['Content-Type'] = 'application/json'
          req.body = dp_hash.to_json
        end

        if response.status == 201
          puts "new datapoints created for analysis #{analysis_id}"
        else
          fail "could not create new datapoints #{response.body}"
        end
      end

      def start_analysis(analysis_id, options)
        defaults = {analysis_action: 'start', without_delay: false}
        options = defaults.merge(options)

        puts "Run analysis is configured with #{options.to_json}"
        response = @conn.post do |req|
          req.url "analyses/#{analysis_id}/action.json"
          req.headers['Content-Type'] = 'application/json'
          req.body = options.to_json
          req.options[:timeout] = 1800 # seconds
        end

        if response.status == 200
          puts "Received request to run analysis #{analysis_id}"
        else
          fail 'Could not start the analysis'
        end
      end

      # Kill the analysis
      # @param analysis [String] Analysis ID to stop
      def kill_analysis(analysis_id)
        analysis_action = {analysis_action: 'stop'}

        response = @conn.post do |req|
          req.url "analyses/#{analysis_id}/action.json"
          req.headers['Content-Type'] = 'application/json'
          req.body = analysis_action.to_json
        end

        if response.status == 200
          puts "Killed analysis #{analysis_id}"
        end
      end

      def kill_all_analyses
        project_ids = get_project_ids
        puts "List of projects ids are: #{project_ids}"

        project_ids.each do |project_id|
          analysis_ids = get_analyses(project_id)
          puts analysis_ids
          analysis_ids.each do |analysis_id|
            puts "Trying to kill #{analysis_id}"
            kill_analysis(analysis_id)
          end
        end
      end

      # Get a list of analyses and the data points
      #
      # @param analysis_id [String] An analysis ID
      def data_point_status(analysis_id = nil)
        data_points = nil
        call_string = nil
        if analysis_id
          call_string = "analyses/#{analysis_id}/status.json"
        else
          call_string = 'analyses/status.json'
        end

        resp = @conn.get call_string, version: 2
        if resp.status == 200
          data_points = JSON.parse(resp.body, symbolize_names: true)[:analyses]
        end

        data_points
      end

      # This is the former version of get data point status. The new version is preferred and allows for
      # checking data points across all analyses.
      def get_datapoint_status(analysis_id, filter = nil)
        data_points = nil
        # get the status of all the entire analysis
        unless analysis_id.nil?
          if filter.nil? || filter == ''
            resp = @conn.get "analyses/#{analysis_id}/status.json"
            if resp.status == 200
              data_points = JSON.parse(resp.body, symbolize_names: true)[:data_points]
            end
          else
            resp = @conn.get "analyses/#{analysis_id}/status.json", jobs: filter
            if resp.status == 200
              data_points = JSON.parse(resp.body, symbolize_names: true)[:data_points]
            end
          end
        end

        data_points
      end

      # Return the JSON (Full) of the datapoint
      def get_datapoint(data_point_id)
        data_point = nil

        resp = @conn.get "/data_points/#{data_point_id}/show_full.json"
        if resp.status == 200
          data_point = JSON.parse resp.body, symbolize_names: true
        end

        data_point
      end

      # Submit a generic analysis. This will use the options that are configured in the JSON file including
      # the analysis type and options. Note that this may not work for all cases were multiple analyses need to run
      # (e.g. single_run, queue_model, lhs)
      #
      # @params formaluation_filename [String] FQP to the formulation file
      # @params analysis_zip_filename [String] FQP to the zip file with the supporting files
      def run_file(formulation_filename, analysis_zip_filename)
        # parse the JSON file to grab the analysis type
        j = JSON.parse(formulation_filename, symbolize_names: true)
        analysis_type = j[:analysis][:problem][:analysis_type]

        run(formulation_filename, analysis_zip_filename, analysis_type)
      end

      # Submit the analysis for running via the API
      #
      # @param formulation_filename [String] Name of the analysis.json file
      # @param analysis_zip_filename [String] Name of the analysis.zip file
      # @param analysis_type [String] Type of analysis to run
      # @param options [Hash] Hash of options
      # @option options [String] :run_data_point_filename Name of ruby file that the server runs -- will be deprecated
      # @option options [String] :push_to_dencity Whether or not to push to DEnCity
      # @option options [String] :batch_run_method Which batch run method to use (batch_run or batch_run_local [no R])
      def run(formulation_filename, analysis_zip_filename, analysis_type,
              options = {})
        defaults = {
            run_data_point_filename: 'run_openstudio_workflow_monthly.rb',
            push_to_dencity: false,
            batch_run_method: 'batch_run'
        }
        options = defaults.merge(options)

        project_options = {}
        project_id = new_project(project_options)

        analysis_options = {
            formulation_file: formulation_filename,
            upload_file: analysis_zip_filename,
            reset_uuids: true,
            push_to_dencity: options[:push_to_dencity]
        }

        analysis_id = new_analysis(project_id, analysis_options)

        run_options = {
            analysis_action: 'start',
            without_delay: false,
            analysis_type: analysis_type,
            simulate_data_point_filename: 'simulate_data_point.rb', # TODO: remove these from server?
            run_data_point_filename: options[:run_data_point_filename]
        }
        start_analysis(analysis_id, run_options)

        # If the analysis is a staged analysis, then go ahead and run batch run
        # because there is no explicit way to tell the system to do it
        if BATCH_RUN_METHODS.include? analysis_type
          run_options = {
              analysis_action: 'start',
              without_delay: false,
              analysis_type: options[:batch_run_method],
              simulate_data_point_filename: 'simulate_data_point.rb',
              run_data_point_filename: options[:run_data_point_filename]
          }
          start_analysis(analysis_id, run_options)
        end

        analysis_id
      end

      def queue_single_run(formulation_filename, analysis_zip_filename, analysis_type,
                           run_data_point_filename = 'run_openstudio_workflow_monthly.rb')
        project_options = {}
        project_id = new_project(project_options)

        analysis_options = {
            formulation_file: formulation_filename,
            upload_file: analysis_zip_filename,
            reset_uuids: true
        }
        analysis_id = new_analysis(project_id, analysis_options)

        run_options = {
            analysis_action: 'start',
            without_delay: false,
            analysis_type: analysis_type,
            simulate_data_point_filename: 'simulate_data_point.rb',
            run_data_point_filename: run_data_point_filename
        }
        start_analysis(analysis_id, run_options)

        analysis_id
      end

      def run_batch_run_across_analyses
        project_options = {}
        project_id = new_project(project_options)

        analysis_options = {
            formulation_file: nil,
            upload_file: nil,
            reset_uuids: true,
        }
        analysis_id = new_analysis(project_id, analysis_options)

        run_options = {
            analysis_action: 'start',
            without_delay: false,
            analysis_type: 'batch_run_analyses',
            simulate_data_point_filename: 'simulate_data_point.rb',
            run_data_point_filename: 'run_openstudio_workflow_monthly.rb'
        }
        start_analysis(analysis_id, run_options)

        analysis_id
      end
    end
  end
end
