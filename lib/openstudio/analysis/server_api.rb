# Class manages the communication with the server.
# Presently, this class is simple and stores all information in hashs
module OpenStudio
  module Analysis
    class ServerApi
      attr_reader :hostname

      def initialize(options = {})
        defaults = {hostname: 'http://localhost:8080'}
        options = defaults.merge(options)
        @logger = Logger.new('faraday.log')

        @hostname = options[:hostname]

        fail 'no host defined for server api class' if @hostname.nil?

        # todo: add support for the proxy

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
          deleted =false
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
        defaults = {project_name: "Project #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"}
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

        #sleep 2  # super cheesy---need to update how this works. Right now there is a good chance to get a
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

      def get_analysis_status_and_json(analysis_id, analysis_type)
        status = nil
        j = nil

        #sleep 2  # super cheesy---need to update how this works. Right now there is a good chance to get a
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

      def download_dataframe(analysis_id, format='rdata', save_directory=".")
        downloaded = false
        file_path_and_name = nil

        response = @conn.get "/analyses/#{analysis_id}/download_data.#{format}?export=true"
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

      def download_variables(analysis_id, format='rdata', save_directory=".")
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

      def download_datapoint(datapoint_id, save_directory=".")
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

      def new_analysis(project_id, options)
        defaults = {analysis_name: nil, reset_uuids: false}
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
            analysis_id = UUID.new.generate
            formulation_json[:analysis][:uuid] = analysis_id

            formulation_json[:analysis][:problem][:workflow].each do |wf|
              wf[:uuid] = UUID.new.generate
              if wf[:arguments]
                wf[:arguments].each do |arg|
                  arg[:uuid] = UUID.new.generate
                end
              end
              if wf[:variables]
                wf[:variables].each do |var|
                  var[:uuid] = UUID.new.generate
                  var[:argument][:uuid] = UUID.new.generate if var[:argument]
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
          analysis_id = UUID.new.generate
          formulation_json[:analysis][:uuid] = analysis_id
        end
        fail "No analysis id defined in analyis.json #{options[:formulation_file]}" if analysis_id.nil?

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

          puts "new analysis created with ID: #{analysis_id}"
        else
          fail 'Could not create new analysis'
        end

        # check if we need to upload the analysis zip file
        if options[:upload_file]
          fail "upload file does not exist #{options[:upload_file]}" unless File.exist?(options[:upload_file])

          payload = {file: Faraday::UploadIO.new(options[:upload_file], 'application/zip')}
          response = @conn_multipart.post "analyses/#{analysis_id}/upload.json", payload

          if response.status == 201
            puts 'Successfully uploaded ZIP file'
          else
            fail response.inspect
          end
        end

        analysis_id
      end

      def upload_datapoint(analysis_id, options)
        defaults = {reset_uuids: false}
        options = defaults.merge(options)

        fail 'No analysis id passed' if analysis_id.nil?
        fail 'No datapoints file passed to new_analysis' unless options[:datapoint_file]
        fail "No datapoints_file exists #{options[:datapoint_file]}" unless File.exist?(options[:datapoint_file])

        dp_hash = JSON.parse(File.open(options[:datapoint_file]).read, symbolize_names: true)

        if options[:reset_uuids]
          dp_hash[:analysis_uuid] = analysis_id
          dp_hash[:uuid] = UUID.new.generate
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

      def run_analysis(analysis_id, options)
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
          puts "Recieved request to run analysis #{analysis_id}"
        else
          fail 'Could not start the analysis'
        end
      end

      def kill_analysis(analysis_id)
        analysis_action = {analysis_action: 'stop'}

        response = @conn.post do |req|
          req.url "analyses/#{analysis_id}/action.json"
          req.headers['Content-Type'] = 'application/json'
          req.body = analysis_action.to_json
        end

        if response.status == 200
          puts "Killed analysis #{analysis_id}"
        else
          # raise "Could not kill the analysis with response of #{response.inspect}"
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
            resp = @conn.get "#{@hostname}/analyses/#{analysis_id}/status.json", jobs: filter
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

      ## here are a bunch of runs that really don't belong here.

      # create a new analysis and run a single model
      def run_single_model(formulation_filename, analysis_zip_filename, run_data_point_filename='run_openstudio_workflow_monthly.rb')
        project_options = {}
        project_id = new_project(project_options)

        analysis_options = {
            formulation_file: formulation_filename,
            upload_file: analysis_zip_filename,
            reset_uuids: true
        }
        analysis_id = new_analysis(project_id, analysis_options)

        # Force this to run in the foreground for now until we can deal with checing the 'analysis state of various anlaysis'
        run_options = {
            analysis_action: "start",
            without_delay: true, # run this in the foreground
            analysis_type: 'single_run',
            allow_multiple_jobs: true,
            use_server_as_worker: true,
            simulate_data_point_filename: 'simulate_data_point.rb',
            run_data_point_filename: run_data_point_filename
        }
        run_analysis(analysis_id, run_options)

        run_options = {
            analysis_action: "start",
            without_delay: false, # run in background
            analysis_type: 'batch_run',
            allow_multiple_jobs: true,
            use_server_as_worker: true,
            simulate_data_point_filename: 'simulate_data_point.rb',
            run_data_point_filename: run_data_point_filename
        }
        run_analysis(analysis_id, run_options)

        analysis_id
      end

      # creates a new analysis and runs rgenoud optimization - number of generations isn't used right now
      def run_rgenoud(formulation_filename, analysis_zip_filename, number_of_generations)
        project_options = {}
        project_id = new_project(project_options)

        analysis_options = {
            formulation_file: formulation_filename,
            upload_file: analysis_zip_filename,
            reset_uuids: true
        }
        analysis_id = new_analysis(project_id, analysis_options)

        run_options = {
            analysis_action: "start",
            without_delay: false,
            analysis_type: 'rgenoud',
            allow_multiple_jobs: true,
            use_server_as_worker: true,
            simulate_data_point_filename: 'simulate_data_point.rb',
            run_data_point_filename: 'run_openstudio_workflow_monthly.rb'
        }
        run_analysis(analysis_id, run_options)

        analysis_id
      end

      def run_lhs(formulation_filename, analysis_zip_filename)
        project_options = {}
        project_id = new_project(project_options)

        analysis_options = {
            formulation_file: formulation_filename,
            upload_file: analysis_zip_filename,
            reset_uuids: true
        }
        analysis_id = new_analysis(project_id, analysis_options)

        run_options = {
            analysis_action: "start",
            without_delay: false,
            analysis_type: 'lhs',
            allow_multiple_jobs: true,
            use_server_as_worker: true,
            simulate_data_point_filename: 'simulate_data_point.rb',
            run_data_point_filename: 'run_openstudio_workflow_monthly.rb'
        }
        run_analysis(analysis_id, run_options)

        run_options = {
            analysis_action: "start",
            without_delay: false, # run in background
            analysis_type: 'batch_run',
            allow_multiple_jobs: true,
            use_server_as_worker: true,
            simulate_data_point_filename: 'simulate_data_point.rb',
            run_data_point_filename: 'run_openstudio_workflow_monthly.rb'
        }
        run_analysis(analysis_id, run_options)

        analysis_id
      end

      def run_analysis_detailed(formulation_filename, analysis_zip_filename,
                                analysis_type, allow_multiple_jobs, server_as_worker, run_data_point_filename)
        project_options = {}
        project_id = new_project(project_options)

        analysis_options = {
            formulation_file: formulation_filename,
            upload_file: analysis_zip_filename,
            reset_uuids: true
        }
        analysis_id = new_analysis(project_id, analysis_options)

        server_as_worker = true if analysis_type == 'optim' || analysis_type == 'rgenoud'
        run_options = {
            analysis_action: "start",
            without_delay: false,
            analysis_type: analysis_type,
            allow_multiple_jobs: allow_multiple_jobs,
            use_server_as_worker: server_as_worker,
            simulate_data_point_filename: 'simulate_data_point.rb',
            run_data_point_filename: run_data_point_filename
        }
        run_analysis(analysis_id, run_options)

        # If the analysis is LHS, then go ahead and run batch run because there is
        # no explicit way to tell the system to do it
        if analysis_type == 'lhs' || analysis_type == 'preflight' || analysis_type == 'single_run'
          run_options = {
              analysis_action: "start",
              without_delay: false,
              analysis_type: 'batch_run',
              allow_multiple_jobs: allow_multiple_jobs,
              use_server_as_worker: server_as_worker,
              simulate_data_point_filename: 'simulate_data_point.rb',
              run_data_point_filename: run_data_point_filename
          }
          run_analysis(analysis_id, run_options)
        end

        analysis_id
      end
    end
  end
end
