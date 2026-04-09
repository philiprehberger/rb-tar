# frozen_string_literal: true

require_relative 'lib/philiprehberger/tar/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-tar'
  spec.version = Philiprehberger::Tar::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'Pure-Ruby tar archive creation, extraction, and gzip compression with filtering, symlink support, and progress callbacks'
  spec.description = 'Pure-Ruby implementation of tar archive creation and extraction using the standard ' \
                     '512-byte block format. Supports adding files from disk or strings, extracting archives, ' \
                     'and listing archive contents without external dependencies.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-tar'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-tar'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-tar/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-tar/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
