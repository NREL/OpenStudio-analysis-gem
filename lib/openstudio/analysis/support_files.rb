# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
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

# OpenStudio::Analysis::SupportFiles is a container to hold other analysis files that may need to be packaged.
# The most common use of support files are weather files, design day files, multiple seed files, worker initialization
# scripts, worker finalization scripts, and general libraries
module OpenStudio
  module Analysis
    class SupportFiles
      attr_reader :files

      # Create a new instance of the support file class
      #
      def initialize
        @files = []
      end

      # Check if the array is empty
      def empty?
        @files.empty?
      end

      # Add a file to the support file list
      #
      # @param path_or_filename [String] Full path of the file to be added.
      # @return [Boolean] Returns false if the file does not exist
      def add(path_or_filename, metadata = {})
        if !File.exist?(path_or_filename) && !Dir.exist?(path_or_filename)
          raise "Path or file does not exist and cannot be added: #{path_or_filename}"
        end

        # only add if it isn't allready in the list
        if @files.find_all { |f| f[:file] == path_or_filename }.empty?
          @files << { file: path_or_filename, metadata: metadata }
        end

        true
      end

      # Add a glob path with the same metadata for all the items
      #
      # @param pattern [String] Pattern to glob. example: /home/user1/files/**/*.rb
      # @return [Boolean] Always returns true
      def add_files(pattern, metadata = {})
        Dir[pattern].each do |f|
          add(f, metadata)
        end

        true
      end

      # Return the first
      def first
        @files.first
      end

      # Return the last
      def last
        @files.last
      end

      # Access a file by an index
      def [](index)
        @files[index]
      end

      # Remove a file from the list
      #
      # @param filename [String] Full name of the file to remove
      def remove(filename)
        @files.delete_if { |f| f[:file] == filename }
      end

      # Return the number of files
      #
      # @return [Integer] Number of items
      def size
        @files.size
      end

      # Iterate over the files
      def each
        @files.each { |i| yield i }
      end

      # Iterate over the files with index
      def each_with_index
        @files.each_with_index { |d, index| yield d, index }
      end

      # remove all the items
      def clear
        @files.clear
      end

      # find the first object. There has to be a better way to do this. Can I just inherit an array?
      def find
        @files.find { |i| yield i }
      end
    end
  end
end
