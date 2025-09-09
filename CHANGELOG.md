# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-12

### Added
- Header checksum validation in Reader — corrupt or malformed tar headers now raise `Error`

### Fixed
- Writer now computes header checksums per POSIX standard (checksum field treated as spaces)
- Add gem-version field and fix ruby-version required in bug report template
- Add alternatives field to feature request template
- Add basic usage example before subsections in README

## [0.2.3] - 2026-04-08

### Changed
- Align gemspec summary with README description.

## [0.2.2] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-28

### Added
- Gzip compression integration with `create_gz`, `extract_gz`, and `list_gz` methods
- File filtering with glob patterns via `include:` and `exclude:` options on `create` and `create_gz`
- Symbolic link support with `Writer#add_symlink` and automatic symlink detection in `Writer#add_file`
- Incremental tar creation with `newer_than:` option to only add files modified after a reference time
- Progress callbacks via `on_progress:` option on `create`, `extract`, `create_gz`, and `extract_gz`

### Changed
- `Reader#list` now includes `:typeflag` and `:linkname` keys in entry hashes
- `Reader#each_entry` now includes `:typeflag` and `:linkname` keys in entry hashes
- `Writer#entry_count` tracks the number of entries written

## [0.1.3] - 2026-03-24

### Changed
- Expand README API table to document all public methods

## [0.1.2] - 2026-03-22

### Changed
- Expanded test coverage to 30+ examples covering edge cases, error paths, and boundary conditions

## [0.1.1] - 2026-03-22

### Changed
- Version bump for republishing

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Create tar archives with files from disk or strings
- Extract tar archives to a directory
- List archive contents without extracting
- Standard 512-byte block format
- Path traversal protection on extraction
- Configurable file modes
