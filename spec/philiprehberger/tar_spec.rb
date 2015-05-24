# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::Tar do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::Tar::VERSION).not_to be_nil
    end
  end

  describe '.create and .list' do
    it 'creates an archive and lists its contents' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'test.tar')

        described_class.create(tar_path) do |t|
          t.add_string('hello.txt', 'Hello, world!')
          t.add_string('data.bin', 'binary data', mode: 0o755)
        end

        entries = described_class.list(tar_path)
        expect(entries.length).to eq(2)
        expect(entries[0][:name]).to eq('hello.txt')
        expect(entries[0][:size]).to eq(13)
        expect(entries[1][:name]).to eq('data.bin')
      end
    end
  end

  describe '.create and .extract' do
    it 'round-trips string content' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'test.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_string('greeting.txt', 'Hello!')
          t.add_string('number.txt', '42')
        end

        described_class.extract(tar_path, to: out_dir)

        expect(File.read(File.join(out_dir, 'greeting.txt'))).to eq('Hello!')
        expect(File.read(File.join(out_dir, 'number.txt'))).to eq('42')
      end
    end

    it 'round-trips files from disk' do
      Dir.mktmpdir do |dir|
        source_file = File.join(dir, 'source.txt')
        File.write(source_file, 'source content')

        tar_path = File.join(dir, 'test.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_file(source_file)
        end

        described_class.extract(tar_path, to: out_dir)

        expect(File.read(File.join(out_dir, 'source.txt'))).to eq('source content')
      end
    end

    it 'round-trips multiple files from disk' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'a.txt'), 'aaa')
        File.write(File.join(dir, 'b.txt'), 'bbb')

        tar_path = File.join(dir, 'multi.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_file(File.join(dir, 'a.txt'))
          t.add_file(File.join(dir, 'b.txt'))
        end

        described_class.extract(tar_path, to: out_dir)

        expect(File.read(File.join(out_dir, 'a.txt'))).to eq('aaa')
        expect(File.read(File.join(out_dir, 'b.txt'))).to eq('bbb')
      end
    end

    it 'round-trips binary content' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'binary.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)
        binary = (0..255).map(&:chr).join

        described_class.create(tar_path) do |t|
          t.add_string('binary.dat', binary)
        end

        described_class.extract(tar_path, to: out_dir)
        expect(File.binread(File.join(out_dir, 'binary.dat'))).to eq(binary)
      end
    end

    it 'preserves file modes' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'modes.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_string('exec.sh', '#!/bin/sh', mode: 0o755)
        end

        entries = described_class.list(tar_path)
        expect(entries[0][:mode]).to eq(0o755)
      end
    end

    it 'round-trips a single large file' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'large.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)
        large_content = 'x' * 100_000

        described_class.create(tar_path) do |t|
          t.add_string('large.txt', large_content)
        end

        described_class.extract(tar_path, to: out_dir)
        expect(File.read(File.join(out_dir, 'large.txt'))).to eq(large_content)
      end
    end
  end

  describe '.extract' do
    it 'raises when destination does not exist' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'test.tar')
        described_class.create(tar_path) do |t|
          t.add_string('a.txt', 'a')
        end

        expect { described_class.extract(tar_path, to: '/nonexistent') }
          .to raise_error(Philiprehberger::Tar::Error, /directory does not exist/)
      end
    end

    it 'creates intermediate directories when extracting' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'nested.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_string('sub/dir/file.txt', 'nested content')
        end

        described_class.extract(tar_path, to: out_dir)
        expect(File.read(File.join(out_dir, 'sub', 'dir', 'file.txt'))).to eq('nested content')
      end
    end

    it 'extracts files with content that spans multiple blocks' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'multiblock.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)
        content = 'A' * 1024

        described_class.create(tar_path) do |t|
          t.add_string('multi.txt', content)
        end

        described_class.extract(tar_path, to: out_dir)
        expect(File.read(File.join(out_dir, 'multi.txt'))).to eq(content)
      end
    end
  end

  describe '.list' do
    it 'returns empty array for empty archive' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'empty.tar')
        described_class.create(tar_path) { |_t| }

        entries = described_class.list(tar_path)
        expect(entries).to eq([])
      end
    end

    it 'returns entry info hashes' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'test.tar')

        described_class.create(tar_path) do |t|
          t.add_string('file.txt', 'content', mode: 0o644)
        end

        entries = described_class.list(tar_path)
        expect(entries.first).to include(:name, :size, :mode)
        expect(entries.first[:name]).to eq('file.txt')
        expect(entries.first[:size]).to eq(7)
      end
    end

    it 'lists multiple entries in order' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'order.tar')

        described_class.create(tar_path) do |t|
          t.add_string('first.txt', 'one')
          t.add_string('second.txt', 'two')
          t.add_string('third.txt', 'three')
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(%w[first.txt second.txt third.txt])
      end
    end

    it 'reports correct sizes for each entry' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'sizes.tar')

        described_class.create(tar_path) do |t|
          t.add_string('empty.txt', '')
          t.add_string('small.txt', 'hi')
          t.add_string('medium.txt', 'a' * 512)
        end

        entries = described_class.list(tar_path)
        expect(entries[0][:size]).to eq(0)
        expect(entries[1][:size]).to eq(2)
        expect(entries[2][:size]).to eq(512)
      end
    end

    it 'reports file mode for each entry' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'modes.tar')

        described_class.create(tar_path) do |t|
          t.add_string('readable.txt', 'r', mode: 0o644)
          t.add_string('executable.sh', 'x', mode: 0o755)
        end

        entries = described_class.list(tar_path)
        expect(entries[0][:mode]).to eq(0o644)
        expect(entries[1][:mode]).to eq(0o755)
      end
    end
  end

  describe Philiprehberger::Tar::Writer do
    it 'uses 512-byte blocks' do
      io = StringIO.new(''.b)
      writer = described_class.new(io)
      writer.add_string('tiny.txt', 'x')
      writer.close

      expect(io.string.bytesize % 512).to eq(0)
    end

    it 'handles empty content' do
      io = StringIO.new(''.b)
      writer = described_class.new(io)
      writer.add_string('empty.txt', '')
      writer.close

      expect(io.string.bytesize % 512).to eq(0)
    end

    it 'writes a ustar header' do
      io = StringIO.new(''.b)
      writer = described_class.new(io)
      writer.add_string('test.txt', 'data')
      writer.close

      header = io.string.byteslice(0, 512)
      expect(header.byteslice(257, 5)).to eq('ustar')
    end

    it 'uses custom name when adding files from disk' do
      Dir.mktmpdir do |dir|
        source = File.join(dir, 'original.txt')
        File.write(source, 'content')

        io = StringIO.new(''.b)
        writer = described_class.new(io)
        writer.add_file(source, name: 'renamed.txt')
        writer.close

        io.rewind
        reader = Philiprehberger::Tar::Reader.new(io)
        entries = reader.each_entry
        expect(entries.first[:name]).to eq('renamed.txt')
      end
    end

    it 'defaults to basename when no name is provided' do
      Dir.mktmpdir do |dir|
        source = File.join(dir, 'myfile.txt')
        File.write(source, 'content')

        io = StringIO.new(''.b)
        writer = described_class.new(io)
        writer.add_file(source)
        writer.close

        io.rewind
        reader = Philiprehberger::Tar::Reader.new(io)
        entries = reader.each_entry
        expect(entries.first[:name]).to eq('myfile.txt')
      end
    end

    it 'handles content exactly 512 bytes' do
      io = StringIO.new(''.b)
      writer = described_class.new(io)
      writer.add_string('exact.txt', 'B' * 512)
      writer.close

      expect(io.string.bytesize % 512).to eq(0)
    end

    it 'handles content of 513 bytes spanning two data blocks' do
      io = StringIO.new(''.b)
      writer = described_class.new(io)
      writer.add_string('over.txt', 'C' * 513)
      writer.close

      expect(io.string.bytesize % 512).to eq(0)
      # header(512) + data(1024) + end-marker(1024) = 2560
      expect(io.string.bytesize).to eq(2560)
    end

    it 'writes end-of-archive marker of two null blocks' do
      io = StringIO.new(''.b)
      writer = described_class.new(io)
      writer.close

      expect(io.string.bytesize).to eq(1024)
      expect(io.string).to eq("\0" * 1024)
    end
  end

  describe Philiprehberger::Tar::Reader do
    it 'reads entries with content' do
      io = StringIO.new(''.b)
      writer = Philiprehberger::Tar::Writer.new(io)
      writer.add_string('a.txt', 'alpha')
      writer.add_string('b.txt', 'beta')
      writer.close

      io.rewind
      reader = described_class.new(io)
      entries = reader.each_entry

      expect(entries.length).to eq(2)
      expect(entries[0][:name]).to eq('a.txt')
      expect(entries[0][:content]).to eq('alpha')
      expect(entries[1][:name]).to eq('b.txt')
      expect(entries[1][:content]).to eq('beta')
    end

    it 'yields entries when a block is given' do
      io = StringIO.new(''.b)
      writer = Philiprehberger::Tar::Writer.new(io)
      writer.add_string('x.txt', 'ex')
      writer.close

      io.rewind
      reader = described_class.new(io)
      names = []
      reader.each_entry { |entry| names << entry[:name] }
      expect(names).to eq(['x.txt'])
    end

    it 'returns empty array for empty archive' do
      io = StringIO.new(''.b)
      writer = Philiprehberger::Tar::Writer.new(io)
      writer.close

      io.rewind
      reader = described_class.new(io)
      entries = reader.each_entry
      expect(entries).to eq([])
    end

    it 'reads entry size correctly' do
      io = StringIO.new(''.b)
      writer = Philiprehberger::Tar::Writer.new(io)
      writer.add_string('sized.txt', 'hello')
      writer.close

      io.rewind
      reader = described_class.new(io)
      entries = reader.each_entry
      expect(entries.first[:size]).to eq(5)
    end

    it 'reads entry mode correctly' do
      io = StringIO.new(''.b)
      writer = Philiprehberger::Tar::Writer.new(io)
      writer.add_string('mode.txt', 'data', mode: 0o755)
      writer.close

      io.rewind
      reader = described_class.new(io)
      entries = reader.each_entry
      expect(entries.first[:mode]).to eq(0o755)
    end

    it 'lists entries without content' do
      io = StringIO.new(''.b)
      writer = Philiprehberger::Tar::Writer.new(io)
      writer.add_string('list1.txt', 'aaa')
      writer.add_string('list2.txt', 'bbb')
      writer.close

      io.rewind
      reader = described_class.new(io)
      listing = reader.list
      expect(listing.length).to eq(2)
      expect(listing.first.keys).to contain_exactly(:name, :size, :mode)
      expect(listing.first[:name]).to eq('list1.txt')
    end

    it 'handles reading from truncated data gracefully' do
      io = StringIO.new(''.b)
      reader = described_class.new(io)
      entries = reader.each_entry
      expect(entries).to eq([])
    end
  end
end
