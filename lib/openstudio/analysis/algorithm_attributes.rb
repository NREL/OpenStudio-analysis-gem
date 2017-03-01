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
        begin
          if Float(attribute_value) != nil
            if Float(attribute_value).abs >= Float('1.0e+19')
              puts "WARNING: Attribute `#{attribute_name}` is greater than 1E19. This may cause failures."
            end
          end
        rescue ArgumentError, TypeError
        end
      end

      def [](name)
        @attributes[name]
      end

      def to_hash(_version = 1)
        @attributes
      end
    end
  end
end
