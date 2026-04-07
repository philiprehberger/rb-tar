# philiprehberger-tar

[![Tests](https://github.com/philiprehberger/rb-tar/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-tar/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-tar.svg)](https://rubygems.org/gems/philiprehberger-tar)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-tar)](https://github.com/philiprehberger/rb-tar/commits/main)

Pure-Ruby tar archive creation, extraction, and gzip compression with filtering, symlink support, and progress callbacks

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

Philiprehberger::Tar.create("archive.tar") do |t|
  t.add_string("hello.txt", "Hello, world!")
end
```

### Creating Archives

```ruby
require "philiprehberger/tar"

Philiprehberger::Tar.create("archive.tar") do |t|
  t.add_file("config.yml")
  t.add_string("hello.txt", "Hello, world!", mode: 0o644)
end
```

### Extracting Archives

```ruby
Philiprehberger::Tar.extract("archive.tar", to: "/tmp/output")
```

### Listing Contents

```ruby
entries = Philiprehberger::Tar.list("archive.tar")
# => [{ name: "config.yml", size: 128, mode: 420, typeflag: "0", linkname: "" }, ...]
```

### Gzip Compression

```ruby
# Create a .tar.gz archive
Philiprehberger::Tar.create_gz("archive.tar.gz") do |t|
  t.add_file("config.yml")
  t.add_string("data.json", '{"key": "value"}')
end

# Extract a .tar.gz archive
Philiprehberger::Tar.extract_gz("archive.tar.gz", to: "/tmp/output")

# List contents of a .tar.gz archive
entries = Philiprehberger::Tar.list_gz("archive.tar.gz")
```

### Find Entry

```ruby
# Find a specific entry in a tar archive
content = Philiprehberger::Tar.find_entry("archive.tar", "config.yml")
# => "key: value" or nil if not found

# Find a specific entry in a .tar.gz archive
content = Philiprehberger::Tar.find_entry_gz("archive.tar.gz", "config.yml")
```

### File Filtering

```ruby
# Include only Ruby files
Philiprehberger::Tar.create("code.tar", include: "*.rb") do |t|
  t.add_string("app.rb", "puts 'hello'")
  t.add_string("readme.md", "# Docs")  # excluded
end

# Exclude test files
Philiprehberger::Tar.create("src.tar", exclude: "test/**") do |t|
  t.add_string("lib/app.rb", "code")
  t.add_string("test/app_test.rb", "test")  # excluded
end

# Combine include and exclude
Philiprehberger::Tar.create("filtered.tar", include: "*.rb", exclude: "test_*.rb") do |t|
  t.add_string("app.rb", "code")
  t.add_string("test_app.rb", "test")  # excluded
end
```

### Symbolic Links

```ruby
Philiprehberger::Tar.create("links.tar") do |t|
  t.add_string("target.txt", "real content")
  t.add_symlink("link.txt", target: "target.txt")
end
```

### Incremental Archives

```ruby
# Only add files modified in the last hour
cutoff = Time.now - 3600
Philiprehberger::Tar.create("recent.tar", newer_than: cutoff) do |t|
  t.add_file("old_file.txt")   # skipped if not modified recently
  t.add_file("new_file.txt")   # included if modified after cutoff
end
```

### Progress Callbacks

```ruby
Philiprehberger::Tar.create("big.tar", on_progress: ->(name, index, total) {
  puts "#{index}/#{total}: #{name}"
}) do |t|
  t.add_string("a.txt", "aaa", total: 2)
  t.add_string("b.txt", "bbb", total: 2)
end

# Progress on extraction
Philiprehberger::Tar.extract("big.tar", to: "/tmp/out", on_progress: ->(name, index, _total) {
  puts "Extracted: #{name} (#{index})"
})
```

## API

| Method | Description |
|--------|-------------|
| `.create(path, include:, exclude:, newer_than:, on_progress:) { \|w\| }` | Create a tar archive with optional filtering and progress |
| `.create_gz(path, include:, exclude:, newer_than:, on_progress:) { \|w\| }` | Create a gzip-compressed tar archive |
| `.extract(path, to:, on_progress:)` | Extract a tar archive to a directory |
| `.extract_gz(path, to:, on_progress:)` | Extract a gzip-compressed tar archive |
| `.list(path)` | List entries in a tar archive |
| `.list_gz(path)` | List entries in a gzip-compressed tar archive |
| `.find_entry(path, name)` | Find an entry by name and return its content (or nil) |
| `.find_entry_gz(path, name)` | Find an entry by name in a gzip-compressed archive |
| `Writer#add_file(path, name:)` | Add a file from disk (auto-detects symlinks) |
| `Writer#add_string(name, content, mode:)` | Add a file from a string |
| `Writer#add_symlink(name, target:)` | Add a symbolic link entry |
| `Writer#close` | Write the end-of-archive marker |
| `Writer#entry_count` | Number of entries written so far |
| `Reader#each_entry { \|e\| }` | Iterate entries with `:name`, `:size`, `:mode`, `:typeflag`, `:linkname`, `:content` |
| `Reader#list` | List entry metadata without reading content |
| `Error` | Raised on invalid paths or missing directories |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-tar)

🐛 [Report issues](https://github.com/philiprehberger/rb-tar/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-tar/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
