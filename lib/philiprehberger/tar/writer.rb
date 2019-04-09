# frozen_string_literal: true

module Philiprehberger
  module Tar
    # Writes tar archives in the standard 512-byte block format.
    class Writer
      BLOCK_SIZE = 512

      # @param io [IO] the output stream
      def initialize(io)
        @io = io
        @entry_count = 0
      end

      # Add a file from the filesystem.
      #
      # @param path [String] path to the file
      # @param name [String, nil] name in the archive (defaults to path basename)
      # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
      # @param total [Integer, nil] total entries for progress callback
      # @return [void]
      def add_file(path, name: nil, on_progress: nil, total: nil)
        name ||= File.basename(path)

        if File.symlink?(path)
          target = File.readlink(path)
          add_symlink(name, target: target, on_progress: on_progress, total: total)
        else
          content = File.binread(path)
          mode = File.stat(path).mode & 0o7777
          write_entry(name, content, mode: mode)
          @entry_count += 1
          on_progress&.call(name, @entry_count, total)
        end
      end

      # Add a file from a string.
      #
      # @param name [String] filename in the archive
      # @param content [String] file content
      # @param mode [Integer] file mode (default: 0644)
      # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
      # @param total [Integer, nil] total entries for progress callback
      # @return [void]
      def add_string(name, content, mode: 0o644, on_progress: nil, total: nil)
        write_entry(name, content, mode: mode)
        @entry_count += 1
        on_progress&.call(name, @entry_count, total)
      end

      # Add a symbolic link entry.
      #
      # @param name [String] link name in the archive
      # @param target [String] link target path
      # @param on_progress [Proc, nil] callback receiving (entry_name, index, total)
      # @param total [Integer, nil] total entries for progress callback
      # @return [void]
      def add_symlink(name, target:, on_progress: nil, total: nil)
        header = build_header(name, 0, 0o777, '2', linkname: target)
        @io.write(header)
        @entry_count += 1
        on_progress&.call(name, @entry_count, total)
      end

      # Write the end-of-archive marker.
      #
      # @return [void]
      def close
        @io.write("\0" * BLOCK_SIZE * 2)
      end

      # Return the number of entries written so far.
      #
      # @return [Integer]
      attr_reader :entry_count

      private

      def write_entry(name, content, mode:)
        header = build_header(name, content.bytesize, mode, '0')
        @io.write(header)
        @io.write(content)
        padding = BLOCK_SIZE - (content.bytesize % BLOCK_SIZE)
        @io.write("\0" * padding) if padding < BLOCK_SIZE
      end

      def build_header(name, size, mode, typeflag, linkname: '')
        header = "\0" * BLOCK_SIZE

        write_field(header, 0, 100, name)
        write_field(header, 100, 8, format('%07o', mode))
        write_field(header, 108, 8, format('%07o', 0))
        write_field(header, 116, 8, format('%07o', 0))
        write_field(header, 124, 12, format('%011o', size))
        write_field(header, 136, 12, format('%011o', Time.now.to_i))
        write_field(header, 156, 1, typeflag)
        write_field(header, 157, 100, linkname)
        write_field(header, 257, 6, 'ustar')
        write_field(header, 263, 2, '00')

        checksum = header.bytes.sum
        write_field(header, 148, 8, "#{format('%06o', checksum)}\u0000 ")

        header
      end

      def write_field(header, offset, length, value)
        bytes = value.b
        bytes.each_byte.with_index do |byte, i|
          break if i >= length

          header.setbyte(offset + i, byte)
        end
      end
    end
  end
end
