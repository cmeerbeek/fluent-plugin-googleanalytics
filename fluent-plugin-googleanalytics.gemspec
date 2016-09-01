# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-googleanalytics"
  gem.version       = "0.9.1"
  gem.authors       = "Coen Meerbeek"
  gem.email         = "cmeerbeek@gmail.com"
  gem.description   = %q{Input plugin for Google Analytics.}
  gem.homepage      = "https://github.com/cmeerbeek/fluent-plugin-googleanalytics"
  gem.summary       = gem.description
  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency "fluentd", [">= 0.10.58", "< 2"]
  gem.add_dependency "google-api-client", "~> 0.9.11"
  gem.add_development_dependency "rake", ">= 0.9.2"
  gem.add_development_dependency "test-unit", ">= 3.1.0"
  gem.license = 'MIT'
end
