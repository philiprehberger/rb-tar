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
  end
end
