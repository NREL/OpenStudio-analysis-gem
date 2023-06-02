# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'spec_helper'

describe OpenStudio::Analysis::ServerApi, type: :integration do
  before :all do
    @host = 'http://localhost:8080'
  end

  context 'create and delete a project', type: :api_integration do
    before :all do
      @api = OpenStudio::Analysis::ServerApi.new
      expect(@api.hostname).to eq(@host)
    end

    it 'should create the project' do
      project_id = @api.new_project({})
      expect(project_id).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/

      # get the projects from the api
      project_ids = @api.get_project_ids
      expect(project_ids.include?(project_id)).to eq true

      # delete the project
      r = @api.delete_project project_id
      expect(r).to be true
    end

    it 'should not be able to delete a non-existent project' do
      r = @api.delete_project('not_a_uuid')
      expect(r).to eq false
    end

    it 'create multiple projects and then delete them all' do
      (1..20).each do |_p|
        project_id = @api.new_project({})
        expect(project_id).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
      end

      r = @api.delete_all
      expect(r).to eq true
    end

    it 'should upload an analysis' do
      puts Dir.pwd
      j = 'spec/files/analysis/medium_office.json'
      z = 'spec/files/analysis/medium_office.zip'
    end
  end
end
