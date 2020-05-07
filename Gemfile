source 'http://rubygems.org'

gemspec

gem 'colored', '~> 1.2'
gem 'dencity'
gem 'openstudio-aws', '~> 0.4.2'

group :test do
  # Don't install coveralls on window because requires devkit for json
  unless Gem.win_platform?
    gem 'coveralls', require: false
  end
  gem 'ci_reporter_rspec'
  gem 'rspec', '~> 3.4'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
