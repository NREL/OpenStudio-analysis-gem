source 'http://rubygems.org'

gemspec

gem 'openstudio-aws', '0.4.2'
gem 'dencity'
gem 'colored', '~> 1.2'

group :test do
  # Don't install coveralls on window because requires devkit for json
  if !Gem.win_platform?
    gem 'coveralls', require: false
  end
  gem 'rspec', '~> 3.4'
  gem 'ci_reporter_rspec'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
