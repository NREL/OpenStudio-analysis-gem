# OpenStudio::Analysis::Algorithm define the algorithm parameters. The module and class names start to conflict
# with OpenStudio's namespace. Be careful adding new classes without first making sure that the namespace conflict
# is clear.
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

      def to_hash(_version = 1)
        @attributes
      end
    end
  end
end
