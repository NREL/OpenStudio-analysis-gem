OpenStudio Analysis Gem
=======================
[![Build Status](https://travis-ci.org/NREL/OpenStudio-analysis-gem.svg?branch=develop)](https://travis-ci.org/NREL/OpenStudio-analysis-gem)
The OpenStudio Analysis Gem is used to communicate files to the OpenStudio Distributed Analysis.

The purpose of this gem is to generate the analysis.json file, analysis.zip, and communicate with the server to upload 
the simulations.

The gem does not create the cluster. Currently the only supported Cloud platform is
Amazon AWS using either [OpenStudio's PAT](https://openstudio.nrel.gov) the [openstudio-aws gem](https://rubygems.org/gems/openstudio-aws) or using [vagrant](http://www.vagrantup.com/).

Instructions
------------

Testing
-------

This gem used RSpec for testing.  To test simple run `rspec` at the command line.


