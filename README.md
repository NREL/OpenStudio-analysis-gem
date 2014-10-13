# OpenStudio Analysis Gem

[![Build Status](https://travis-ci.org/NREL/OpenStudio-analysis-gem.svg?branch=develop)](https://travis-ci.org/NREL/OpenStudio-analysis-gem) [![Dependency Status](https://www.versioneye.com/user/projects/540a2fe5ccc023dd23000002/badge.svg?style=flat)](https://www.versioneye.com/user/projects/540a2fe5ccc023dd23000002)

The OpenStudio Analysis Gem is used to communicate files to the OpenStudio Distributed Analysis.

The purpose of this gem is to generate the analysis.json file, analysis.zip, and communicate with the server to upload 
the simulations.

This gem does not create the cluster. Currently the only supported Cloud platform is
Amazon AWS using either [OpenStudio's PAT](https://openstudio.nrel.gov) the [openstudio-aws gem](https://rubygems.org/gems/openstudio-aws) or using [vagrant](http://www.vagrantup.com/).

## Instructions

There are two ways to create an OpenStudio Analysis description:
* Use the Excel Translator


* Programmatically

```
analysis = OpenStudio::Analysis.create
analysis.seed_model = "local/dir/seed.osm"
analysis.name = "Analysis Name"

# override existing workflow from a file by
analysis.workflow = OpenStudio::Analysis::Workflow.load_from_file(...)

# add measures to the workflow
wf = analysis.workflow
wf.add_measure("path_to_measure")
wf.add_measure("path_to_measure_2")

# or allow the system to search for the measure based on default_measure_paths
OpenStudio::Analysis.measure_paths = ['measures', '../project_specific_measures']
wf.add_measure_by_name('measure_name')

# make a measure's argument a variable
m = wf.add_measure("path_to_measure_3")
m.make_variable('variable_argument_name', 'discrete')

m = wf.add_measure('path_to_measure_4')
m.make_variable('variable_argument_name', 'pivot')
m.argument_static_value('variable_argument_name', value)

```


## Testing


This gem used RSpec for testing.  To test simple run `rspec` at the command line.


