require "bundler"
Bundler.setup

require "rake"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "openstudio/analysis/version"

task :gem => :build
task :build do
  system "gem build openstudio-analysis.gemspec"
end

desc "build and install gem locally"
task :install => :build do
  system "gem install openstudio-analysis-#{OpenStudio::Analysis::VERSION}.gem --no-ri --no-rdoc"
end

task :release => :build do
  system "git tag -a v#{OpenStudio::Analysis::VERSION} -m 'Tagging #{OpenStudio::Analysis::VERSION}'"
  system "git push --tags"
  system "gem push openstudio-analysis-#{OpenStudio::Analysis::VERSION}.gem"
  system "rm openstudio-analysis-#{OpenStudio::Analysis::VERSION}.gem"
end

RSpec::Core::RakeTask.new("spec") do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end

RSpec::Core::RakeTask.new('spec:progress') do |spec|
  spec.rspec_opts = %w(--format progress)
  spec.pattern = "spec/**/*_spec.rb"
end

task :default => :spec

desc "import files from other repos"
task :import_files do
  puts "Importing data from other repos until this repo is self contained"
  # Copy data from github openstudio source

  os_file = "./lib/openstudio/lib/os-aws.rb"
  system "curl -S -s -L -o #{os_file} https://raw.github.com/NREL/OpenStudio/develop/openstudiocore/ruby/cloud/aws.rb.in"
  if File.exists?(os_file)
    system "ruby -i -pe 'puts \"# NOTE: Do not modify this file as it is copied over. Modify the source file and rerun rake import_files\" if $.==1' #{os_file}"
    system "sed -i '' 's/\${CMAKE_VERSION_MAJOR}.\${CMAKE_VERSION_MINOR}.\${CMAKE_VERSION_PATCH}/#{OpenStudio::Analysis::OPENSTUDIO_VERSION}/g' #{os_file}"
  end

  os_file = "./lib/openstudio/lib/mongoid.yml.template"
  system "curl -S -s -L -o #{os_file} https://raw.github.com/NREL/OpenStudio/develop/openstudiocore/ruby/cloud/mongoid.yml.template"

  os_file = "./lib/openstudio/lib/server_script.sh"
  system "curl -S -s -L -o #{os_file} https://raw.github.com/NREL/OpenStudio/develop/openstudiocore/ruby/cloud/server_script.sh"
  if File.exists?(os_file)
    system "ruby -i -pe 'puts \"# NOTE: Do not modify this file as it is copied over. Modify the source file and rerun rake import_files\" if $.==2' #{os_file}"
  end

  os_file = "./lib/openstudio/lib/worker_script.sh.template"
  system "curl -S -s -L -o #{os_file} https://raw.github.com/NREL/OpenStudio/develop/openstudiocore/ruby/cloud/worker_script.sh.template"
  if File.exists?(os_file)
    system "ruby -i -pe 'puts \"# NOTE: Do not modify this file as it is copied over. Modify the source file and rerun rake import_files\" if $.==2' #{os_file}"
  end
end

desc "uninstall all openstudio-analysis gems"
task :uninstall do

  system "gem uninstall openstudio-analysis -a"
end

desc "reinstall the gem (uninstall, build, and reinstall"
task :reinstall => [:uninstall, :install]

