# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bundleup/version'

Gem::Specification.new do |spec|
  spec.name          = 'bundleup'
  spec.version       = Bundleup::VERSION
  spec.authors       = ['Chulki Lee']
  spec.email         = ['chulki.lee@gmail.com']

  spec.summary       = 'update bundle deps'
  spec.description   = 'update bundle deps'
  spec.homepage      = 'https://github.com/chulkilee/bundleup'
  spec.license       = 'MIT'

  spec.files         = Dir['README.md', 'LICENSE', 'lib/**/*', 'exe/*']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rugged'
  spec.add_dependency 'thor'
end
