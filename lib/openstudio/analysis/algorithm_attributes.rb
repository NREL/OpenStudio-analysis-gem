# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2023, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
      ANALYSIS_TYPES = ['spea_nrel', 'rgenoud', 'nsga_nrel', 'lhs', 'preflight', 'morris', 'sobol', 'doe', 'fast99', 'ga', 'gaisl', 'single_run', 'repeat_run', 'batch_run']

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
