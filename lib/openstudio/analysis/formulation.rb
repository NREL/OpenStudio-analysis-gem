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

        # TODO: convert to nice display name
        @name = display_name
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
        {
            workflow: @workflow.to_hash
        }
      end
    end
  end
end