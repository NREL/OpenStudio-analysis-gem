lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
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
  s.license = 'BSD'

  s.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  s.bindir = 'exe'
  s.executables = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.required_ruby_version = '~> 3.2.2'

  s.add_dependency 'bcl', '~> 0.9.1'
  s.add_dependency 'dencity', '~> 0.1.0'
  s.add_dependency 'faraday', '~> 1.10.4'
  s.add_dependency 'roo', '~> 2.8.3'
  s.add_dependency 'rubyzip', '~> 2.3.0'
  s.add_dependency 'semantic', '~> 1.4'

  s.add_development_dependency 'json-schema', '~> 4'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.10'
  s.add_development_dependency 'rubocop', '1.50'
  s.add_development_dependency 'rubocop-checkstyle_formatter', '0.6.0'
end
