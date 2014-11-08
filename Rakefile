require 'bundler'
Bundler.setup

require 'rspec/core/rake_task'

# Always create spec reports
require 'ci/reporter/rake/rspec'

# Gem tasks
require 'bundler/gem_tasks'

RSpec::Core::RakeTask.new('spec:unit') do |spec|
  spec.rspec_opts = %w(--format progress)
  spec.pattern = FileList['spec/openstudio/**/*_spec.rb']
end

RSpec::Core::RakeTask.new('spec:integration') do |spec|
  spec.rspec_opts = %w(--format progress)
  spec.pattern = FileList['spec/integration/**/*_spec.rb']
end

task 'spec:unit' => 'ci:setup:rspec'
task 'spec:integration' => 'ci:setup:rspec'

task :default => 'spec:unit'
