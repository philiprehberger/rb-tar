# frozen_string_literal: true

module Philiprehberger
  module Tar
    # Reads and extracts tar archives.
    class Reader
      BLOCK_SIZE = 512

      # @param io [IO] the input stream
      def initialize(io)
        @io = io
      end

      # Iterate over each entry in the archive.
      #
      # @yield [Hash] entry info with :name, :size, :mode, :typeflag, :linkname, :content keys
      # @return [Array<Hash>] entries if no block given
      def each_entry(&block)
        entries = []

        loop do
          header = @io.read(BLOCK_SIZE)
          break if header.nil? || header.bytesize < BLOCK_SIZE
          break if header == "\0" * BLOCK_SIZE

          entry = parse_header(header)
          break if entry[:name].empty?

          if entry[:typeflag] == '2'
            # Symlink entry has no content
            entry[:content] = ''
          else
            content = read_content(entry[:size])
            entry[:content] = content
          end

          if block
            block.call(entry)
          else
            entries << entry
          end
        end

        entries unless block
      end

      # Check whether the archive contains an entry with the given name,
      # without reading entry content.
      #
      # @param name [String] the entry name to search for
      # @return [Boolean] true if the entry exists in the archive
      def entry?(name)
        loop do
          header = @io.read(BLOCK_SIZE)
          break if header.nil? || header.bytesize < BLOCK_SIZE
          break if header == "\0" * BLOCK_SIZE

          entry = parse_header(header)
          break if entry[:name].empty?

          return true if entry[:name] == name

          skip_content(entry[:size]) unless entry[:typeflag] == '2'
        end

        false
      end

      # List all entries without reading content.
      #
      # @return [Array<Hash>] entry info hashes with :name, :size, :mode, :typeflag, :linkname keys
      def list
        result = []

        loop do
          header = @io.read(BLOCK_SIZE)
          break if header.nil? || header.bytesize < BLOCK_SIZE
          break if header == "\0" * BLOCK_SIZE

          entry = parse_header(header)
          break if entry[:name].empty?

          result << { name: entry[:name], size: entry[:size], mode: entry[:mode],
                      typeflag: entry[:typeflag], linkname: entry[:linkname] }
          skip_content(entry[:size]) unless entry[:typeflag] == '2'
        end

        result
      end

      private

      def parse_header(header)
        validate_checksum!(header)

        name = read_field(header, 0, 100)
        mode = read_field(header, 100, 8).to_i(8)
        size = read_field(header, 124, 12).to_i(8)
        typeflag = header.byteslice(156, 1)
        linkname = read_field(header, 157, 100)

        { name: name, size: size, mode: mode, typeflag: typeflag, linkname: linkname }
      end

      def validate_checksum!(header)
        stored = read_field(header, 148, 8).to_i(8)
        computed = 0
        header.each_byte.with_index do |byte, i|
          computed += i >= 148 && i < 156 ? 0x20 : byte
        end
        return if stored == computed

        raise Error, "invalid tar header checksum (expected #{computed}, got #{stored})"
      end

      def read_field(header, offset, length)
        field = header.byteslice(offset, length)
        field.delete("\0").strip
      end

      def read_content(size)
        return ''.b if size <= 0

        content = @io.read(size)
        padding = BLOCK_SIZE - (size % BLOCK_SIZE)
        @io.read(padding) if padding < BLOCK_SIZE
        content
      end

      def skip_content(size)
        return if size <= 0

        blocks = (size + BLOCK_SIZE - 1) / BLOCK_SIZE
        @io.read(blocks * BLOCK_SIZE)
      end
    end
  end
end
