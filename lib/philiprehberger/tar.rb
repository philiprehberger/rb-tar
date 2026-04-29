# frozen_string_literal: true

require 'zlib'
require_relative 'tar/version'
require_relative 'tar/writer'
require_relative 'tar/reader'

module Philiprehberger
  module Tar
    class Error < StandardError; end

    # Create a tar archive.
    #
    # @param output_path [String] path to the output tar file
    # @param include [String, Array<String>, nil] glob pattern(s) to include
    # @param exclude [String, Array<String>, nil] glob pattern(s) to exclude
    # @param newer_than [Time, nil] only add files modified after this time
    # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
    # @yield [Writer] the writer for adding files
    # @return [void]
    def self.create(output_path, include: nil, exclude: nil, newer_than: nil, on_progress: nil, &block)
      File.open(output_path, 'wb') do |io|
        writer = Writer.new(io)
        if include || exclude || newer_than
          filtered_writer = FilteredWriter.new(writer, include: include, exclude: exclude,
                                                       newer_than: newer_than, on_progress: on_progress)
          block.call(filtered_writer)
        else
          block.call(on_progress ? ProgressWriter.new(writer, on_progress: on_progress) : writer)
        end
        writer.close
      end
    end

    # Create a gzip-compressed tar archive (.tar.gz).
    #
    # @param output_path [String] path to the output .tar.gz file
    # @param include [String, Array<String>, nil] glob pattern(s) to include
    # @param exclude [String, Array<String>, nil] glob pattern(s) to exclude
    # @param newer_than [Time, nil] only add files modified after this time
    # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
    # @yield [Writer] the writer for adding files
    # @return [void]
    def self.create_gz(output_path, include: nil, exclude: nil, newer_than: nil, on_progress: nil, &block)
      File.open(output_path, 'wb') do |file_io|
        gz = Zlib::GzipWriter.new(file_io)
        writer = Writer.new(gz)
        if include || exclude || newer_than
          filtered_writer = FilteredWriter.new(writer, include: include, exclude: exclude,
                                                       newer_than: newer_than, on_progress: on_progress)
          block.call(filtered_writer)
        else
          block.call(on_progress ? ProgressWriter.new(writer, on_progress: on_progress) : writer)
        end
        writer.close
        gz.close
      end
    end

    # Extract a tar archive to a directory.
    #
    # @param input_path [String] path to the tar file
    # @param to [String] destination directory
    # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
    # @return [void]
    def self.extract(input_path, to:, on_progress: nil)
      raise Error, "directory does not exist: #{to}" unless Dir.exist?(to)

      File.open(input_path, 'rb') do |io|
        extract_from_io(io, to: to, on_progress: on_progress)
      end
    end

    # Extract a gzip-compressed tar archive (.tar.gz) to a directory.
    #
    # @param input_path [String] path to the .tar.gz file
    # @param to [String] destination directory
    # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
    # @return [void]
    def self.extract_gz(input_path, to:, on_progress: nil)
      raise Error, "directory does not exist: #{to}" unless Dir.exist?(to)

      File.open(input_path, 'rb') do |file_io|
        gz = Zlib::GzipReader.new(file_io)
        extract_from_io(gz, to: to, on_progress: on_progress)
        gz.close
      end
    end

    # List entries in a tar archive.
    #
    # @param input_path [String] path to the tar file
    # @return [Array<Hash>] entry info hashes with :name, :size, :mode, :typeflag, :linkname keys
    def self.list(input_path)
      File.open(input_path, 'rb') do |io|
        Reader.new(io).list
      end
    end

    # List entries in a gzip-compressed tar archive.
    #
    # @param input_path [String] path to the .tar.gz file
    # @return [Array<Hash>] entry info hashes with :name, :size, :mode, :typeflag, :linkname keys
    def self.list_gz(input_path)
      File.open(input_path, 'rb') do |file_io|
        gz = Zlib::GzipReader.new(file_io)
        entries = Reader.new(gz).list
        gz.close
        entries
      end
    end

    # Find an entry by name in a tar archive and return its content.
    #
    # @param input_path [String] path to the tar file
    # @param name [String] entry name to search for
    # @return [String, nil] entry content or nil if not found
    def self.find_entry(input_path, name)
      File.open(input_path, 'rb') do |io|
        find_entry_in_io(io, name)
      end
    end

    # Find an entry by name in a gzip-compressed tar archive and return its content.
    #
    # @param input_path [String] path to the .tar.gz file
    # @param name [String] entry name to search for
    # @return [String, nil] entry content or nil if not found
    def self.find_entry_gz(input_path, name)
      File.open(input_path, 'rb') do |file_io|
        gz = Zlib::GzipReader.new(file_io)
        result = find_entry_in_io(gz, name)
        gz.close
        result
      end
    end

    # Check whether a tar archive contains an entry with the given name.
    #
    # Skips entry content while scanning headers, so this is cheaper than
    # {.find_entry} when only existence matters.
    #
    # @param input_path [String] path to the tar file
    # @param name [String] entry name to look up
    # @return [Boolean] true if the archive contains the entry
    def self.entry?(input_path, name)
      File.open(input_path, 'rb') do |io|
        Reader.new(io).entry?(name)
      end
    end

    # Check whether a gzip-compressed tar archive contains an entry with the
    # given name.
    #
    # @param input_path [String] path to the .tar.gz file
    # @param name [String] entry name to look up
    # @return [Boolean] true if the archive contains the entry
    def self.entry_gz?(input_path, name)
      File.open(input_path, 'rb') do |file_io|
        gz = Zlib::GzipReader.new(file_io)
        result = Reader.new(gz).entry?(name)
        gz.close
        result
      end
    end

    # Internal: search for an entry by name in an IO-like object.
    #
    # @param io [IO] the input stream
    # @param name [String] entry name to search for
    # @return [String, nil] entry content or nil if not found
    def self.find_entry_in_io(io, name)
      reader = Reader.new(io)
      reader.each_entry do |entry|
        return entry[:content] if entry[:name] == name
      end
      nil
    end
    private_class_method :find_entry_in_io

    # Internal: extract entries from an IO-like object.
    #
    # @param io [IO] the input stream
    # @param to [String] destination directory
    # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
    # @return [void]
    def self.extract_from_io(io, to:, on_progress: nil)
      reader = Reader.new(io)
      index = 0

      reader.each_entry do |entry|
        dest = File.join(to, entry[:name])

        if dest.start_with?('..') || entry[:name].include?('..')
          raise Error, "path traversal detected: #{entry[:name]}"
        end

        dir = File.dirname(dest)
        FileUtils.mkdir_p(dir)

        if entry[:typeflag] == '2'
          # Symbolic link
          File.symlink(entry[:linkname], dest) unless File.exist?(dest)
        else
          File.binwrite(dest, entry[:content])
          File.chmod(entry[:mode], dest) if entry[:mode].positive?
        end

        index += 1
        on_progress&.call(entry[:name], index, nil)
      end
    end
    private_class_method :extract_from_io

    # Check if a filename matches a set of glob patterns.
    #
    # @param name [String] filename to test
    # @param patterns [Array<String>] glob patterns
    # @return [Boolean]
    def self.matches_glob?(name, patterns)
      patterns.any? { |pat| File.fnmatch(pat, name, File::FNM_PATHNAME | File::FNM_DOTMATCH) }
    end
    private_class_method :matches_glob?

    # A wrapper around Writer that applies include/exclude/newer_than filters.
    class FilteredWriter
      # @param writer [Writer] the underlying writer
      # @param include [String, Array<String>, nil] glob pattern(s) to include
      # @param exclude [String, Array<String>, nil] glob pattern(s) to exclude
      # @param newer_than [Time, nil] only add files modified after this time
      # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
      def initialize(writer, include: nil, exclude: nil, newer_than: nil, on_progress: nil)
        @writer = writer
        @include_patterns = include ? Array(include) : nil
        @exclude_patterns = exclude ? Array(exclude) : nil
        @newer_than = newer_than
        @on_progress = on_progress
      end

      # Add a file from the filesystem, applying filters.
      def add_file(path, name: nil, total: nil)
        check_name = name || File.basename(path)
        return unless passes_filter?(check_name)
        return if @newer_than && File.mtime(path) <= @newer_than

        @writer.add_file(path, name: name, on_progress: @on_progress, total: total)
      end

      # Add a file from a string, applying include/exclude filters.
      def add_string(name, content, mode: 0o644, total: nil)
        return unless passes_filter?(name)

        @writer.add_string(name, content, mode: mode, on_progress: @on_progress, total: total)
      end

      # Add a symlink, applying include/exclude filters.
      def add_symlink(name, target:, total: nil)
        return unless passes_filter?(name)

        @writer.add_symlink(name, target: target, on_progress: @on_progress, total: total)
      end

      private

      def passes_filter?(name)
        if @include_patterns && !Tar.send(:matches_glob?, name, @include_patterns)
          return false
        end
        if @exclude_patterns && Tar.send(:matches_glob?, name, @exclude_patterns)
          return false
        end

        true
      end
    end

    # A wrapper around Writer that adds progress callbacks without filtering.
    class ProgressWriter
      def initialize(writer, on_progress:)
        @writer = writer
        @on_progress = on_progress
      end

      def add_file(path, name: nil, total: nil)
        @writer.add_file(path, name: name, on_progress: @on_progress, total: total)
      end

      def add_string(name, content, mode: 0o644, total: nil)
        @writer.add_string(name, content, mode: mode, on_progress: @on_progress, total: total)
      end

      def add_symlink(name, target:, total: nil)
        @writer.add_symlink(name, target: target, on_progress: @on_progress, total: total)
      end
    end
  end
end
