# coding: utf-8
lib = File.expand_path '../lib', __FILE__
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib

require 'tablegen/version'

Gem::Specification.new do |spec|
  spec.name          = "tablegen"
  spec.version       = TableGen::VERSION
  spec.authors       = ["cfillion"]
  spec.email         = ["tablegen@cfillion.tk"]
  spec.summary       = %q{plain text table generator}
  spec.homepage      = "https://github.com/cfillion/TableGen"
  spec.license       = "LGPL-3.0+"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency 'minitest', '~> 5.4'
  spec.add_development_dependency "rake"
end
