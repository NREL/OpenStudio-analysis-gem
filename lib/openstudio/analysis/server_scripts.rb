# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# OpenStudio::Analysis::ServerScripts is a container to hold the analysis and data_point server scripts.
module OpenStudio
  module Analysis
    class ServerScripts
      attr_reader :files

      # Create a new instance of the Server Scripts file class
      # Server scripts are run at either the analysis or data_point level and are either initialization or finalization
      # file: full path to the script
      # arguments: array of arguments for the script
      # init_or_final: specify either 'initialization' or 'finalization'
      # server_or_data_point: specify either 'analysis' or 'data_point'
      #
      def initialize
        @files = []
      end

      def add(file, arguments, init_or_final = 'initialization', server_or_data_point = 'data_point')
      
        file_path = File.expand_path(file)
        if !File.exist?(file_path)
          raise ArgumentError, "File at '#{file_path}' does not exist"
        end
    
        if init_or_final != 'initialization' && init_or_final != 'finalization'
          raise ArgumentError, "init_or_final must be 'initialization' or 'finalization'"
        end
        
        if server_or_data_point != 'analysis' && server_or_data_point != 'data_point'
          raise ArgumentError, "server_or_data_point must be 'analysis' or 'data_point'"
        end
        
        if !arguments.is_a?(Array)
          raise ArgumentError, "arguments must be an array"
        end
    
        file = {
          file: file_path,
          arguments: arguments,
          init_or_final: init_or_final,
          server_or_data_point: server_or_data_point
        }
        @files << file
        true
      end
      
      # Check if the array is empty
      def empty?
        @files.empty?
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
