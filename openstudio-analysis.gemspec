lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'openstudio/analysis/version'

Gem::Specification.new do |s|
  s.name = 'openstudio-analysis'
  s.version = OpenStudio::Analysis::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Nicholas Long']
  s.email = ['Nicholas.Long@nrel.gov']
  s.homepage = 'http://openstudio.nrel.gov'
  s.summary = 'Create JSON, ZIP to communicate with OpenStudio Distributed Analysis in the Cloud'
  s.description = 'Basic classes for generating the files needed for OpenStudio-Server'
  s.license = 'LGPL'

  s.required_ruby_version = '>= 2.0'
  s.required_rubygems_version = '>= 1.3.6'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_dependency 'faraday', '~> 0.8'
  s.add_dependency 'nokogiri', '~> 1.6'
  s.add_dependency 'roo', '~> 2.4'
  s.add_dependency 'rubyzip', '~> 1.2' # Should be at 1.0 because of jruby
  s.add_dependency 'semantic', '~> 1.4'
  s.add_dependency 'bcl', '~> 0.5.5'
  s.add_dependency 'dencity', '~> 0.1.0'

  s.add_development_dependency 'bundler', '~> 1.7'
  s.add_development_dependency 'rake', '~> 11.1'
end
