# OpenStudio formulation class handles the generation of the OpenStudio Analysis format.
module OpenStudio
  module Analysis
    class Formulation

      attr_accessor :seed_model
      attr_accessor :display_name

      attr_accessor :workflow

      # Create an instance of the OpenStudio::Analysis::Formulation
      #
      # @param display_name [String] Display name of the project.
      # @return [Object] An OpenStudio::Analysis::Formulation object
      def initialize(display_name)
        @display_name = display_name
      end

      # Initialize or return the current workflow object
      #
      # @return [Object] An OpenStudio::Analysis::Workflow object
      def workflow
        @workflow ||= OpenStudio::Analysis::Workflow.new
      end

      # return the JSON.
      #
      # @param version [Integer] Version of the format to return
      def to_hash(version = 1)
        if version == 1
          {
              analysis: {
                  name: @display_name.snake_case,
                  display_name: @display_name,
                  problem: {
                      workflow: @workflow.to_hash
                  },
                  file_format_version: version
              }
          }
        else
          fail "Version #{version} not defined for #{self.class} and #{__method__}"
        end
      end
    end
  end
end