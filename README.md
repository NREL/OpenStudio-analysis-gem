# OpenStudio Analysis Gem

[![Build Status](https://travis-ci.org/NREL/OpenStudio-analysis-gem.svg?branch=develop)](https://travis-ci.org/NREL/OpenStudio-analysis-gem) [![Dependency Status](https://www.versioneye.com/user/projects/540a2fe5ccc023dd23000002/badge.svg?style=flat)](https://www.versioneye.com/user/projects/540a2fe5ccc023dd23000002) [![Coverage Status](https://coveralls.io/repos/NREL/OpenStudio-analysis-gem/badge.svg?branch=develop)](https://coveralls.io/r/NREL/OpenStudio-analysis-gem?branch=develop)

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
    analysis = OpenStudio::Analysis.create('Analysis Name')
    analysis.seed_model = 'local/dir/seed.osm'
    analysis.weather_file = 'local/dir/USA_CO_Golden-NREL.724666_TMY3.epw'
    
    # override existing workflow from a file by
    analysis.workflow = OpenStudio::Analysis::Workflow.load_from_file(...)
    
    # add measures to the workflow
    wf = analysis.workflow
    def add_measure_from_path(instance_name, instance_display_name, local_path_to_measure)
    wf.add_measure_from_path('instance_name', 'Display name', 'path_to_measure')
    wf.add_measure_from_path('instance_name_2', 'Display name two', 'path_to_measure_2')
    
    # make a measure's argument a variable
    m = wf.add_measure_from_path('instance_name_3', 'Display name three', 'path_to_measure_3')
    m.make_variable('variable_argument_name', 'discrete')
    
    m = wf.add_measure_from_path('instance_name_4', 'Display name four', 'path_to_measure_4')
    m.make_variable('variable_argument_name', 'pivot')
    m.argument_value('variable_argument_name', value)
    
    # Save off the analysis files and a static data point
    run_dir = 'local/run'
    analysis.save("#{run_dir}/analysis.json")
    analysis.save_zip("#{run_dir}/analysis.zip")
    analysis.save_static_data_point("#{run_dir}/data_point.zip")
    ```

* Running Datapoints with Workflow Gem

    ```
    require 'openstudio-workflow'
    
    run_dir = 'local/run'
    OpenStudio::Workflow.extract_archive("#{run_dir}/analysis.zip", run_dir)
    
    options = {
        problem_filename: 'analysis.json',
        datapoint_filename: 'data_point.json',
        analysis_root_path: run_dir
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    k.run
    ```
    
* Server API

    ```
    
    
    ```


## Testing

This gem used RSpec for testing.  To test simply run `rspec` at the command line.

# Todos

In the programmatic interface there are still several items that would be nice to have.

* Check the type of measure being added and make sure that it is in the right workflow (e.g. no energyplus measures before rubymeasures)
* add reverse translator from existing analysis.jsons
* more explicit run workflows. For example, add workflow steps for running energyplus, openstudio translator, radiance, etc
* more explicit assignment of the analyses that can run. This would be nice:

    ```
    a = OpenStudio::Analysis.create("new analysis")
    a.analysis_type('single_run')
    ```

* adding mulitple seed models
* adding multiple weather files

