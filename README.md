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

| Method | Description |
|--------|-------------|
| `.create(output_path) { \|t\| }` | Create a tar archive |
| `.extract(input_path, to: dir)` | Extract archive to directory |
| `.list(input_path)` | List archive entries |
| `Writer#add_file(path, name:)` | Add a file from disk |
| `Writer#add_string(name, content, mode:)` | Add a file from a string |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
