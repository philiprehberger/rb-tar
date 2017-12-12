# frozen_string_literal: true

require_relative 'tar/version'
require_relative 'tar/writer'
require_relative 'tar/reader'

module Philiprehberger
  module Tar
    class Error < StandardError; end

    # Create a tar archive.
    #
    # @param output_path [String] path to the output tar file
    # @yield [Writer] the writer for adding files
    # @return [void]
    def self.create(output_path, &block)
      File.open(output_path, 'wb') do |io|
        writer = Writer.new(io)
        block.call(writer)
        writer.close
      end
    end

    # Extract a tar archive to a directory.
    #
    # @param input_path [String] path to the tar file
    # @param to [String] destination directory
    # @return [void]
    def self.extract(input_path, to:)
      raise Error, "directory does not exist: #{to}" unless Dir.exist?(to)

      File.open(input_path, 'rb') do |io|
        reader = Reader.new(io)
        reader.each_entry do |entry|
          dest = File.join(to, entry[:name])

          if dest.start_with?('..') || entry[:name].include?('..')
            raise Error,
                  "path traversal detected: #{entry[:name]}"
          end

          dir = File.dirname(dest)
          FileUtils.mkdir_p(dir)

          File.binwrite(dest, entry[:content])
          File.chmod(entry[:mode], dest) if entry[:mode].positive?
        end
      end
    end

    # List entries in a tar archive.
    #
    # @param input_path [String] path to the tar file
    # @return [Array<Hash>] entry info hashes with :name, :size, :mode keys
    def self.list(input_path)
      File.open(input_path, 'rb') do |io|
        Reader.new(io).list
      end
    end
  end
end
