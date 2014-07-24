require 'bundler'
Bundler.setup

require 'rake'
require 'rspec/core/rake_task'

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'openstudio/analysis/version'

task gem: :build
desc 'build gem locally'
task :build do
  system 'gem build openstudio-analysis.gemspec'
end

desc 'build and install gem locally'
task install: :build do
  system "gem install openstudio-analysis-#{OpenStudio::Analysis::VERSION}.gem --no-ri --no-rdoc"
end

desc 'release gem (this builds, pushes to rubygems, and tags in github'
task release: :build do
  # add catch if there are local changes not committed to crash
  system "git tag -a v#{OpenStudio::Analysis::VERSION} -m 'Tagging #{OpenStudio::Analysis::VERSION}'"
  system 'git push --tags'
  system "gem push openstudio-analysis-#{OpenStudio::Analysis::VERSION}.gem"
  system "rm openstudio-analysis-#{OpenStudio::Analysis::VERSION}.gem"
end

RSpec::Core::RakeTask.new('spec:unit') do |spec|
  spec.rspec_opts = %w(--format progress --format CI::Reporter::RSpec)
  spec.pattern = FileList['spec/openstudio/**/*_spec.rb']
end

RSpec::Core::RakeTask.new('spec:integration') do |spec|
  spec.rspec_opts = %w(--format progress --format CI::Reporter::RSpec)
  spec.pattern = FileList['spec/integration/**/*_spec.rb']
end

task default: 'spec:unit'

desc 'import files from other repos'
task :import_files do
  # tbd
end

desc 'uninstall all openstudio-analysis gems'
task :uninstall do

  system 'gem uninstall openstudio-analysis -a'
end

desc 'reinstall the gem (uninstall, build, and reinstall'
task reinstall: [:uninstall, :install]
