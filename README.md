# philiprehberger-tar

[![Tests](https://github.com/philiprehberger/rb-tar/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-tar/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-tar.svg)](https://rubygems.org/gems/philiprehberger-tar)
[![License](https://img.shields.io/github/license/philiprehberger/rb-tar)](LICENSE)

Pure-Ruby tar archive creation and extraction

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-tar"
```

Or install directly:

```bash
gem install philiprehberger-tar
```

## Usage

```ruby
require "philiprehberger/tar"

Philiprehberger::Tar.create('archive.tar') do |t|
  t.add_file('config.yml')
  t.add_string('hello.txt', 'Hello, world!', mode: 0644)
end
```

### Extracting Archives

```ruby
Philiprehberger::Tar.extract('archive.tar', to: '/tmp/output')
```

### Listing Contents

```ruby
entries = Philiprehberger::Tar.list('archive.tar')
# => [{ name: 'config.yml', size: 128, mode: 420 }, ...]
```

### Adding Files from Strings

```ruby
Philiprehberger::Tar.create('data.tar') do |t|
  t.add_string('readme.txt', 'This is the readme', mode: 0644)
  t.add_string('data.json', '{"key": "value"}', mode: 0644)
end
```

## API

### `Philiprehberger::Tar`

| Method | Description |
|--------|-------------|
| `.create(output_path) { \|writer\| }` | Create a tar archive; yields a `Writer` instance |
| `.extract(input_path, to:)` | Extract all entries to the given directory |
| `.list(input_path)` | Return an array of entry hashes (`:name`, `:size`, `:mode`) |
| `Error` | Custom error class raised on invalid paths or missing directories |

### `Philiprehberger::Tar::Writer`

| Method | Description |
|--------|-------------|
| `BLOCK_SIZE` | Archive block size constant (`512`) |
| `#initialize(io)` | Wrap a writable IO stream for tar output |
| `#add_file(path, name:)` | Add a file from disk; `name` defaults to the basename |
| `#add_string(name, content, mode:)` | Add a file from a string; `mode` defaults to `0644` |
| `#close` | Write the two-block end-of-archive marker |

### `Philiprehberger::Tar::Reader`

| Method | Description |
|--------|-------------|
| `BLOCK_SIZE` | Archive block size constant (`512`) |
| `#initialize(io)` | Wrap a readable IO stream for tar input |
| `#each_entry { \|entry\| }` | Yield each entry hash (`:name`, `:size`, `:mode`, `:content`); returns an array if no block given |
| `#list` | Return an array of entry metadata hashes (`:name`, `:size`, `:mode`) without reading content |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
