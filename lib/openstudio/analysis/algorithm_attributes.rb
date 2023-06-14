# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# OpenStudio::Analysis::Algorithm define the algorithm parameters. The module and class names start to conflict
# with OpenStudio's namespace. Be careful adding new classes without first making sure that the namespace conflict
# is clear.
module OpenStudio
  module Analysis
    class AlgorithmAttributes
      # Create a new instance of the parameters for an algorithm 
      #
      def initialize
        @attributes = {
        "seed": nil,
        "failed_f_value": 1000000000000000000,
        "debug_messages": 1
        }
      end

      # these are the allowed analysis types
      ANALYSIS_TYPES = ['diag', 'doe', 'fast99', 'ga', 'gaisl', 'lhs', 'morris', 'nsga_nrel', 'optim',
                        'preflight', 'pso', 'repeat_run', 'rgenoud', 'single_run', 'sobol', 'spea_nrel']

      def set_attribute(attribute_name, attribute_value)
        @attributes[attribute_name] = attribute_value
        begin
          unless Float(attribute_value).nil?
            if Float(attribute_value).abs >= Float('1.0e+19')
              raise "ERROR: Attribute `#{attribute_name}` is greater than 1E19. This may cause failures."
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
