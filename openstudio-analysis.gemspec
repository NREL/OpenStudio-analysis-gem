lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "openstudio/analysis/version"

Gem::Specification.new do |s|
  s.name = "openstudio-analysis"
  s.version = OpenStudio::Analysis::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Nicholas Long"]
  s.email = ["Nicholas.Long@nrel.gov"]
  s.homepage = 'http://openstudio.nrel.gov'
  s.summary = "Create JSON, ZIP to communicate with OpenStudio Distributed Analysis in the Cloud"
  s.description = "Basic classes for generating the files needed for OpenStudio-Server"
  s.license = "LGPL"

  s.required_ruby_version = ">= 2.0"
  s.required_rubygems_version = ">= 1.3.6"

  s.add_runtime_dependency("json")
  s.add_runtime_dependency("faraday")
  s.add_runtime_dependency("uuid")

  s.add_dependency("roo", ["~> 1.12.2"])
  s.add_dependency("rubyzip", ["~> 1.1.0"])

  s.files = Dir.glob("lib/**/*") + %w(README.md CHANGELOG.md Rakefile)
  s.test_files = Dir.glob("spec/**/*")
  s.require_path = "lib"
end


