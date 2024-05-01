source 'http://rubygems.org'

gemspec

gem 'colored', '~> 1.2'
gem 'openstudio-aws', '~> 0.4.2'
gem 'bcl-gem', github: 'NREL/bcl-gem', ref: 'develop'

group :test do
  # Don't install coveralls on window because requires devkit for json
  unless Gem.win_platform?
    gem 'coveralls', require: false
  end
  gem 'ci_reporter_rspec'
end
