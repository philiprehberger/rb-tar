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

    it 'restores file permissions on extraction' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'perms.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_string('script.sh', '#!/bin/sh', mode: 0o755)
          t.add_string('config.yml', 'key: val', mode: 0o600)
        end

        described_class.extract(tar_path, to: out_dir)

        expect(File.stat(File.join(out_dir, 'script.sh')).mode & 0o7777).to eq(0o755)
        expect(File.stat(File.join(out_dir, 'config.yml')).mode & 0o7777).to eq(0o600)
      end
    end

    it 'preserves permissions from disk files' do
      Dir.mktmpdir do |dir|
        source = File.join(dir, 'myexec.sh')
        File.write(source, '#!/bin/sh')
        File.chmod(0o755, source)

        tar_path = File.join(dir, 'diskperms.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_file(source)
        end

        described_class.extract(tar_path, to: out_dir)

        extracted = File.join(out_dir, 'myexec.sh')
        expect(File.stat(extracted).mode & 0o7777).to eq(0o755)
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

    it 'includes typeflag and linkname in listing' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'meta.tar')

        described_class.create(tar_path) do |t|
          t.add_string('file.txt', 'data')
          t.add_symlink('link.txt', target: 'file.txt')
        end

        entries = described_class.list(tar_path)
        expect(entries[0][:typeflag]).to eq('0')
        expect(entries[1][:typeflag]).to eq('2')
        expect(entries[1][:linkname]).to eq('file.txt')
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

    it 'tracks entry count' do
      io = StringIO.new(''.b)
      writer = described_class.new(io)
      expect(writer.entry_count).to eq(0)
      writer.add_string('a.txt', 'a')
      expect(writer.entry_count).to eq(1)
      writer.add_string('b.txt', 'b')
      expect(writer.entry_count).to eq(2)
      writer.close
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
      expect(listing.first.keys).to contain_exactly(:name, :size, :mode, :typeflag, :linkname)
      expect(listing.first[:name]).to eq('list1.txt')
    end

    it 'handles reading from truncated data gracefully' do
      io = StringIO.new(''.b)
      reader = described_class.new(io)
      entries = reader.each_entry
      expect(entries).to eq([])
    end

    it 'reads symlink entries' do
      io = StringIO.new(''.b)
      writer = Philiprehberger::Tar::Writer.new(io)
      writer.add_string('target.txt', 'data')
      writer.add_symlink('link.txt', target: 'target.txt')
      writer.close

      io.rewind
      reader = described_class.new(io)
      entries = reader.each_entry

      expect(entries.length).to eq(2)
      expect(entries[1][:typeflag]).to eq('2')
      expect(entries[1][:linkname]).to eq('target.txt')
      expect(entries[1][:name]).to eq('link.txt')
    end
  end

  describe 'symlink support' do
    it 'writes and reads symlink entries' do
      io = StringIO.new(''.b)
      writer = Philiprehberger::Tar::Writer.new(io)
      writer.add_symlink('mylink', target: 'real_file.txt')
      writer.close

      io.rewind
      reader = Philiprehberger::Tar::Reader.new(io)
      entries = reader.each_entry

      expect(entries.length).to eq(1)
      expect(entries[0][:name]).to eq('mylink')
      expect(entries[0][:typeflag]).to eq('2')
      expect(entries[0][:linkname]).to eq('real_file.txt')
      expect(entries[0][:content]).to eq('')
    end

    it 'extracts symlinks to the filesystem' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'symlink.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_string('target.txt', 'symlink target content')
          t.add_symlink('link.txt', target: 'target.txt')
        end

        described_class.extract(tar_path, to: out_dir)

        link_path = File.join(out_dir, 'link.txt')
        expect(File.symlink?(link_path)).to be true
        expect(File.readlink(link_path)).to eq('target.txt')
        expect(File.read(link_path)).to eq('symlink target content')
      end
    end

    it 'auto-detects symlinks when adding files from disk' do
      Dir.mktmpdir do |dir|
        target_file = File.join(dir, 'real.txt')
        File.write(target_file, 'real content')
        link_file = File.join(dir, 'symlink.txt')
        File.symlink('real.txt', link_file)

        io = StringIO.new(''.b)
        writer = Philiprehberger::Tar::Writer.new(io)
        writer.add_file(link_file, name: 'symlink.txt')
        writer.close

        io.rewind
        reader = Philiprehberger::Tar::Reader.new(io)
        entries = reader.each_entry

        expect(entries.length).to eq(1)
        expect(entries[0][:typeflag]).to eq('2')
        expect(entries[0][:linkname]).to eq('real.txt')
      end
    end

    it 'lists symlinks with typeflag and linkname' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'symlinkl.tar')

        described_class.create(tar_path) do |t|
          t.add_string('file.txt', 'content')
          t.add_symlink('alias.txt', target: 'file.txt')
        end

        entries = described_class.list(tar_path)
        expect(entries[1][:typeflag]).to eq('2')
        expect(entries[1][:linkname]).to eq('file.txt')
      end
    end
  end

  describe 'gzip compression' do
    it 'creates and extracts a .tar.gz archive' do
      Dir.mktmpdir do |dir|
        gz_path = File.join(dir, 'archive.tar.gz')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create_gz(gz_path) do |t|
          t.add_string('hello.txt', 'Hello, gzip!')
          t.add_string('data.bin', 'binary data', mode: 0o755)
        end

        expect(File.exist?(gz_path)).to be true
        # Verify it's actually gzip (magic bytes)
        magic = File.binread(gz_path, 2)
        expect(magic.bytes).to eq([0x1f, 0x8b])

        described_class.extract_gz(gz_path, to: out_dir)

        expect(File.read(File.join(out_dir, 'hello.txt'))).to eq('Hello, gzip!')
        expect(File.read(File.join(out_dir, 'data.bin'))).to eq('binary data')
      end
    end

    it 'lists entries in a .tar.gz archive' do
      Dir.mktmpdir do |dir|
        gz_path = File.join(dir, 'list.tar.gz')

        described_class.create_gz(gz_path) do |t|
          t.add_string('a.txt', 'aaa')
          t.add_string('b.txt', 'bbb')
        end

        entries = described_class.list_gz(gz_path)
        expect(entries.length).to eq(2)
        expect(entries.map { |e| e[:name] }).to eq(%w[a.txt b.txt])
      end
    end

    it 'round-trips large content through gzip' do
      Dir.mktmpdir do |dir|
        gz_path = File.join(dir, 'large.tar.gz')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)
        large = 'Z' * 50_000

        described_class.create_gz(gz_path) do |t|
          t.add_string('big.txt', large)
        end

        described_class.extract_gz(gz_path, to: out_dir)
        expect(File.read(File.join(out_dir, 'big.txt'))).to eq(large)
      end
    end

    it 'compressed file is smaller than uncompressed' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'test.tar')
        gz_path = File.join(dir, 'test.tar.gz')
        content = 'repeated text ' * 1000

        described_class.create(tar_path) do |t|
          t.add_string('data.txt', content)
        end

        described_class.create_gz(gz_path) do |t|
          t.add_string('data.txt', content)
        end

        expect(File.size(gz_path)).to be < File.size(tar_path)
      end
    end

    it 'raises when extract_gz destination does not exist' do
      Dir.mktmpdir do |dir|
        gz_path = File.join(dir, 'test.tar.gz')
        described_class.create_gz(gz_path) do |t|
          t.add_string('a.txt', 'a')
        end

        expect { described_class.extract_gz(gz_path, to: '/nonexistent') }
          .to raise_error(Philiprehberger::Tar::Error, /directory does not exist/)
      end
    end

    it 'handles symlinks in gzip archives' do
      Dir.mktmpdir do |dir|
        gz_path = File.join(dir, 'symlink.tar.gz')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create_gz(gz_path) do |t|
          t.add_string('target.txt', 'target data')
          t.add_symlink('link.txt', target: 'target.txt')
        end

        described_class.extract_gz(gz_path, to: out_dir)

        link_path = File.join(out_dir, 'link.txt')
        expect(File.symlink?(link_path)).to be true
        expect(File.readlink(link_path)).to eq('target.txt')
      end
    end
  end

  describe 'file filtering' do
    it 'includes only files matching include pattern' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'filtered.tar')

        described_class.create(tar_path, include: '*.rb') do |t|
          t.add_string('app.rb', 'puts "hello"')
          t.add_string('readme.md', '# Readme')
          t.add_string('lib.rb', 'module Lib; end')
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(%w[app.rb lib.rb])
      end
    end

    it 'excludes files matching exclude pattern' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'excluded.tar')

        described_class.create(tar_path, exclude: '*.log') do |t|
          t.add_string('app.rb', 'code')
          t.add_string('debug.log', 'log data')
          t.add_string('error.log', 'error data')
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(['app.rb'])
      end
    end

    it 'supports both include and exclude patterns' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'both.tar')

        described_class.create(tar_path, include: '*.rb', exclude: 'test_*.rb') do |t|
          t.add_string('app.rb', 'code')
          t.add_string('test_app.rb', 'test')
          t.add_string('lib.rb', 'lib code')
          t.add_string('readme.md', 'docs')
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(%w[app.rb lib.rb])
      end
    end

    it 'supports array of patterns' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'multi.tar')

        described_class.create(tar_path, include: ['*.rb', '*.yml']) do |t|
          t.add_string('app.rb', 'code')
          t.add_string('config.yml', 'key: val')
          t.add_string('readme.md', 'docs')
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(%w[app.rb config.yml])
      end
    end

    it 'excludes with glob path patterns' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'glob.tar')

        described_class.create(tar_path, exclude: 'test/**') do |t|
          t.add_string('lib/app.rb', 'code')
          t.add_string('test/app_test.rb', 'test')
          t.add_string('test/helper.rb', 'helper')
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(['lib/app.rb'])
      end
    end

    it 'filters work with gzip archives' do
      Dir.mktmpdir do |dir|
        gz_path = File.join(dir, 'filtered.tar.gz')

        described_class.create_gz(gz_path, include: '*.rb') do |t|
          t.add_string('app.rb', 'code')
          t.add_string('readme.md', 'docs')
        end

        entries = described_class.list_gz(gz_path)
        expect(entries.map { |e| e[:name] }).to eq(['app.rb'])
      end
    end

    it 'filters symlinks by name' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'filtsym.tar')

        described_class.create(tar_path, include: '*.rb') do |t|
          t.add_string('app.rb', 'code')
          t.add_symlink('link.rb', target: 'app.rb')
          t.add_symlink('link.txt', target: 'app.rb')
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(%w[app.rb link.rb])
      end
    end
  end

  describe 'incremental tar creation (newer_than)' do
    it 'only includes files newer than the given time' do
      Dir.mktmpdir do |dir|
        old_file = File.join(dir, 'old.txt')
        File.write(old_file, 'old content')
        old_mtime = Time.now - 7200
        File.utime(old_mtime, old_mtime, old_file)

        new_file = File.join(dir, 'new.txt')
        File.write(new_file, 'new content')

        tar_path = File.join(dir, 'incremental.tar')
        cutoff = Time.now - 3600

        described_class.create(tar_path, newer_than: cutoff) do |t|
          t.add_file(old_file)
          t.add_file(new_file)
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(['new.txt'])
      end
    end

    it 'includes all files when newer_than is very old' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'a.txt'), 'a')
        File.write(File.join(dir, 'b.txt'), 'b')

        tar_path = File.join(dir, 'all.tar')

        described_class.create(tar_path, newer_than: Time.new(2000, 1, 1)) do |t|
          t.add_file(File.join(dir, 'a.txt'))
          t.add_file(File.join(dir, 'b.txt'))
        end

        entries = described_class.list(tar_path)
        expect(entries.length).to eq(2)
      end
    end

    it 'excludes all files when newer_than is in the future' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'a.txt'), 'a')

        tar_path = File.join(dir, 'none.tar')

        described_class.create(tar_path, newer_than: Time.now + 3600) do |t|
          t.add_file(File.join(dir, 'a.txt'))
        end

        entries = described_class.list(tar_path)
        expect(entries).to be_empty
      end
    end

    it 'does not apply newer_than to string entries' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'strings.tar')

        described_class.create(tar_path, newer_than: Time.now + 3600) do |t|
          t.add_string('always.txt', 'always included')
        end

        entries = described_class.list(tar_path)
        expect(entries.length).to eq(1)
        expect(entries[0][:name]).to eq('always.txt')
      end
    end

    it 'combines newer_than with include/exclude filters' do
      Dir.mktmpdir do |dir|
        old_rb = File.join(dir, 'old.rb')
        File.write(old_rb, 'old ruby')
        old_mtime = Time.now - 7200
        File.utime(old_mtime, old_mtime, old_rb)

        new_rb = File.join(dir, 'new.rb')
        File.write(new_rb, 'new ruby')

        new_log = File.join(dir, 'new.log')
        File.write(new_log, 'new log')

        tar_path = File.join(dir, 'combo.tar')
        cutoff = Time.now - 3600

        described_class.create(tar_path, include: '*.rb', newer_than: cutoff) do |t|
          t.add_file(old_rb)
          t.add_file(new_rb)
          t.add_file(new_log)
        end

        entries = described_class.list(tar_path)
        expect(entries.map { |e| e[:name] }).to eq(['new.rb'])
      end
    end
  end

  describe 'progress callbacks' do
    it 'calls on_progress for each entry during create' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'progress.tar')
        progress_calls = []

        described_class.create(tar_path, on_progress: lambda { |name, idx, total|
          progress_calls << { name: name, index: idx, total: total }
        }) do |t|
          t.add_string('a.txt', 'aaa', total: 3)
          t.add_string('b.txt', 'bbb', total: 3)
          t.add_string('c.txt', 'ccc', total: 3)
        end

        expect(progress_calls.length).to eq(3)
        expect(progress_calls[0]).to eq({ name: 'a.txt', index: 1, total: 3 })
        expect(progress_calls[1]).to eq({ name: 'b.txt', index: 2, total: 3 })
        expect(progress_calls[2]).to eq({ name: 'c.txt', index: 3, total: 3 })
      end
    end

    it 'calls on_progress during extract' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'progress.tar')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create(tar_path) do |t|
          t.add_string('x.txt', 'xxx')
          t.add_string('y.txt', 'yyy')
        end

        progress_calls = []
        described_class.extract(tar_path, to: out_dir, on_progress: lambda { |name, idx, total|
          progress_calls << { name: name, index: idx, total: total }
        })

        expect(progress_calls.length).to eq(2)
        expect(progress_calls[0][:name]).to eq('x.txt')
        expect(progress_calls[0][:index]).to eq(1)
        expect(progress_calls[1][:name]).to eq('y.txt')
        expect(progress_calls[1][:index]).to eq(2)
      end
    end

    it 'calls on_progress during create_gz' do
      Dir.mktmpdir do |dir|
        gz_path = File.join(dir, 'progress.tar.gz')
        progress_calls = []

        described_class.create_gz(gz_path, on_progress: lambda { |name, _idx, _total|
          progress_calls << name
        }) do |t|
          t.add_string('a.txt', 'aaa')
          t.add_string('b.txt', 'bbb')
        end

        expect(progress_calls).to eq(%w[a.txt b.txt])
      end
    end

    it 'calls on_progress during extract_gz' do
      Dir.mktmpdir do |dir|
        gz_path = File.join(dir, 'progress.tar.gz')
        out_dir = File.join(dir, 'out')
        Dir.mkdir(out_dir)

        described_class.create_gz(gz_path) do |t|
          t.add_string('p.txt', 'ppp')
        end

        progress_calls = []
        described_class.extract_gz(gz_path, to: out_dir, on_progress: lambda { |name, idx, _total|
          progress_calls << { name: name, index: idx }
        })

        expect(progress_calls.length).to eq(1)
        expect(progress_calls[0][:name]).to eq('p.txt')
      end
    end

    it 'calls on_progress for symlink entries' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'symprog.tar')
        progress_calls = []

        described_class.create(tar_path, on_progress: lambda { |name, _idx, _total|
          progress_calls << name
        }) do |t|
          t.add_string('file.txt', 'data')
          t.add_symlink('link.txt', target: 'file.txt')
        end

        expect(progress_calls).to eq(%w[file.txt link.txt])
      end
    end

    it 'works with filtering and progress combined' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'filtprog.tar')
        progress_calls = []

        described_class.create(tar_path, include: '*.rb', on_progress: lambda { |name, _idx, _total|
          progress_calls << name
        }) do |t|
          t.add_string('app.rb', 'code')
          t.add_string('readme.md', 'docs')
          t.add_string('lib.rb', 'lib')
        end

        expect(progress_calls).to eq(%w[app.rb lib.rb])
      end
    end
  end

  describe 'checksum validation' do
    it 'reads a valid archive without error' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'valid.tar')
        described_class.create(tar_path) do |t|
          t.add_string('hello.txt', 'hello')
        end

        entries = described_class.list(tar_path)
        expect(entries.size).to eq(1)
        expect(entries.first[:name]).to eq('hello.txt')
      end
    end

    it 'raises Error on a corrupt header' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'corrupt.tar')
        described_class.create(tar_path) do |t|
          t.add_string('hello.txt', 'hello')
        end

        data = File.binread(tar_path)
        data.setbyte(0, (data.getbyte(0) + 1) % 256)
        File.binwrite(tar_path, data)

        expect { described_class.list(tar_path) }.to raise_error(
          Philiprehberger::Tar::Error, /invalid tar header checksum/
        )
      end
    end

    it 'includes expected and actual checksum in error message' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'corrupt2.tar')
        described_class.create(tar_path) do |t|
          t.add_string('test.txt', 'data')
        end

        data = File.binread(tar_path)
        data.setbyte(10, (data.getbyte(10) + 1) % 256)
        File.binwrite(tar_path, data)

        expect { described_class.list(tar_path) }.to raise_error(
          Philiprehberger::Tar::Error, /expected \d+, got \d+/
        )
      end
    end

    it 'validates checksum on each_entry as well' do
      Dir.mktmpdir do |dir|
        tar_path = File.join(dir, 'corrupt3.tar')
        described_class.create(tar_path) do |t|
          t.add_string('a.txt', 'aaa')
        end

        data = File.binread(tar_path)
        data.setbyte(5, (data.getbyte(5) + 1) % 256)
        File.binwrite(tar_path, data)

        expect do
          File.open(tar_path, 'rb') do |io|
            Philiprehberger::Tar::Reader.new(io).each_entry { |_e| }
          end
        end.to raise_error(Philiprehberger::Tar::Error, /invalid tar header checksum/)
      end
    end
  end
end
