# OpenStudio::Analysis::Algorithm to define the algorithm parameters
module OpenStudio
  module Analysis
    class AlgorithmAttributes

      # Create a new instance of an algorithm
      #
      def initialize
        @attributes = {}
      end

      def set_attribute(attribute_name, attribute_value)
        @attributes[attribute_name] = attribute_value
      end

      def to_hash(version = 1)
        @attributes
      end
    end
  end
end