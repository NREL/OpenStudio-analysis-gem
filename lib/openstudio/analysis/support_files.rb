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

      # Add a file to the support file list
      #
      # @param path_or_filename [String] Full path of the file to be added.
      # @return [Boolean] Returns false if the file does not exist
      def add(path_or_filename, metadata = {})
        if !File.exist?(path_or_filename) && !Dir.exist?(path_or_filename)
          fail "Path or file does not exist and cannot be added: #{path_or_filename}"
        end

        # only add if it isn't allready in the list
        if @files.find_all { |f| f[:file] == path_or_filename }.empty?
          @files << {file: path_or_filename, metadata: metadata}
        end

        true
      end

      # Add a glob path with the same metadata for all the items
      #
      # @param pattern [String] Pattern to glob. example: /home/user1/files/**/*.rb
      # @return [Boolean] Returns false if the file does not exist
      def add_files(pattern, metadata = {})
        Dir[pattern].each do |f|
          add(f, metadata)
        end

        true
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

      # remove all the items
      def clear
        @files.clear
      end

    end
  end
end
