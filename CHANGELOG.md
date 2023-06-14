OpenStudio(R) Analysis Gem Change Log
==================================

Version 1.3.4
-------------
* Update licenses
* Add download_zip, download_osm, download_osw, download_reports attributes to OSA
* Add cli_verbose, cli_debug, initialize_worker_timeout, run_workflow_timeout, upload_results_timeout attributes to OSA

Version 1.3.3
-------------
* Add arguments to .save_osa_zip() to add all files in weather and/or seed directories to zip file. defaults to false.

Version 1.3.2
-------------
* Add array of search paths to .convert_osw() to find measures in various directories.
* warn if :weather_file and :seed_model are not defined.
* use :file_paths in the OSW to search for :seed_model and :weather_file.
* add .stat and .ddy files to analysis.zip if in same directory as .epw defined in :weather_file.
* use :measure_paths in OSW to search for measures. 

Version 1.3.1
-------------
* Add method to delete a Variable:  **analysis.remove_variable()**
* fix bug related to multiple calls to analysis.to_hash deleting variables
* Add PSO and Optim to allowed algorithms 

Version 1.3.0
-------------
* Create an OSA from an OSW:  **analysis.convert_osw()**
* Add output variables and objective functions:  **analysis.add_output()**
* Add server initialization and finalization scripts: **analysis.server_scripts.add()**
* Set algorithm attributes:  **analysis.algorithm.set_attribute()**
* Set algorithm type:  **analysis.analysis_type()**
* Add additional library/data files:  **analysis.libraries.add()**
* create analysis.json:  **File.write('analysis.json',JSON.pretty_generate(analysis.to_hash))**
* create analysis.zip:  **analysis.save_osa_zip('analysis.zip')**

Version 1.2.0
-------------
* master -> main
* Remove support for Ruby 2.5. Only support Ruby ~> 2.7.0
* BCL ~> 0.7.0  
* Use GitHub actions for CI

Version 1.1.0
-------------
* Allow for blank :seed, :weather_file and :workflow sections of OSA

Version 1.0.6
-------------
* Always include ../lib to the file paths to search

Version 1.0.5
-------------
* Upgrade to latest BCL (0.6.1)
* Remove the need for the measure.json (which has been deprecated in BCL gem). Now parses the measure.xml.
* Upgrade Faraday (1.0.1)
* Remove dependency on Nokogiri.

Version 1.0.4
-------------
* Update dependency Nokogiri

Version 1.0.3
-------------
* Update dependencies roo and rubyzip

Version 1.0.2
-------------
* Updates required for OpenStudio 3x
* Require Ruby ~> 2.5.1
* Update to Nokogiri ~> 1.8.2 (required for Ruby 2.5 on Windows)

Version 1.0.1
-------------
* Add support for Ruby 2.5.1 (keeping support for 2.2)
* Lock version of Roo to older version 
* Updated copyright dates and remove old LGPL license. License is not LGPL but a BSD-style license.

Version 1.0.0
-------------
This is the first official release in quite some time. This includes many changes which unfortunately have not been 
cataloged. The changes from 0.4.5 include:

* Requires ruby > 2.1.
* Default path to ServerApi logfile to ~/os_server_api.log. This can be overridden by setting the log_path options key in the initializer.
* Fix get_datapoint_status for new version of API where data_points are under analysis
* Fix boolean data type in datapoints translator
* Allow __skip__ variable in datapoints translator
* Fix bug in batch datapoints to look for outputs_json, not outputs when importing the definition of the outputs JSON file.
* Allow "None" as an argument in batch datapoints. This will allow the measure to be added without setting any of the arguments. Useful for adding Reporting Measures to the workflow.
* Use more recent version of BCL gem for underscoring strings
* When creating OSWs from batch datapoints, set the default run_directory to ./run
* fix get_datapoint method. show_full is no longer a valid endpoint in the new server code 
* Change seed_model to seed_file in OSWs generated from the translator
* Add more unit tests
* Catch null arguments when translating from OSA/OSD to OSW
* Note that pre.rc1 was yanked from Rubygems.
* Remove allow_multiple_jobs and server_as_worker options. These are by defaulted to true now.
* Remove uncertain strings from end of uncertainty distributions
* Remove measures eval path for CSV import
* Add diag analysis type to server_api run method
* Remove support for Rubies < 2.0 and > 2.0.
* Add json extension to formulation name upon save if none exists
* Add zip extension to formulation zip upon save if none exists
* In upload_datapoint, allows set the analysis_id in the file to the one passed.
* Remove reading JSON from custom_csv method.
* Fixed bug in workflow translator which caused errors in server models
* Updated gem versions to converge across the OpenStudio Analysis Framework platforms

Version 0.4.4
------------------
* Increment objective function count only if they are true
* Do not add an output if the variable name has already been added

Version 0.4.3
------------------
* Add defaults to the OpenStudio::Analysis::ServerApi .run method.
* Bug fix for path to the measure if there was more than one depth of the directory.
* Add measure_definition_directory_local to store the path to the original measure.
* run_analysis will be deprecated in 0.5.0. Use start_analysis instead of run_analysis.
* Less stringent check on column names in Excel which caused errors at times.
* Do not error out when a measure argument is a String or Choice and does not contain Enumerations.
* New data point status API helper to list all the data points across all the analyses if desired.
* If the user sets a std dev or delta x on a uniform or discrete variable, allow it to persist. This allows certain algorithms (e.g. rgenoud) to use the data.
* New class OpenStudio::Weather::Epw to handle pulling data out of weather files.
* Deprecate the old ERB templates for creating the analysis.json via the Excel translator

Version 0.4.2
-------------
* Bug fix when adding measure from path, this now sets the correct argument name.
* Fix namespace conflict with OpenStudio::Logger and OpenStudio::Time
* Create method for saving the Analysis Zip file (save_analysis_zip)

Version 0.4.1
-------------
* Bug fix to address the spec/files directory being prepended to the measures

Version 0.4.0
-------------
* Add programmatic interface. This is now used when translating the Excel file into the JSON.

Version 0.3.7
-------------
* Worker initialization and finalization scripts
* Do not allow the file to process if the Measure Display Names are not unique

Version 0.3.6
-------------
* Allow multiple measure paths. Will search by order for the measure.
* Add AWS Tag in the Settings

Version 0.3.5
--------------
* Add delete_project method
* Integration testing
* Return status and filename of downlaoded files
* Methods for removing models from the Excel translator
* Return detailed analyses on a project
* Download database

Version 0.3.4
-------------
* BUG FIX: Measures were not being added to zip file

Version 0.3.3
-------------
* More unit tests
* Allow a UUID model name to be automatically generated if the model name is not specified
* Short name added to the variables input and output section of the spreadsheet. This required adding a new column and is not backwards compatible

Version 0.3.2
--------------
* Support both relative and absolute paths in the spreadsheet
* Helper methods for submitting analyses
* Add get_analysis method to Server API to get the status of an analysis

Version 0.3.1
--------------
* Grab the first EPW file, not the first file
* Download various formats via server API

Version 0.3.0
--------------
* Remove the column for Sampling Method. That is now part of the analysis config.
* All variables need static values now
* Updated output tab to add more information about the outputs if available
* Remove hardcoded baseline exception

Version 0.2.3
--------------
* Support for optional variables
* Display names and Machine names in the models now
* More error checking

Version 0.1.14
--------------
* Symbolize headers parsed from excel file.


Version 0.1.12/13
-------------
* Add machine name to pivot variables
* Force generation of unique UUIDs
* Add data types to arguments and variables for XML based measures
* Move Pivot variable type to Type (not sample method)

Version 0.1.11
-------------
* Add cluster name and openstudio server version
* Make the booleans in run_options actual booleans

Version 0.1.10
-------------
* Add output variables to the spreadsheet as a separate tab

Version 0.1.9
-------------
* Downcase checking of variable data types

Version 0.1.9
-------------
* Clean up the "delete_mes" in the JSONs
* Added discrete variables to the spreadsheet and bumped version

Version 0.1.8
-------------
* Parsing of Proxy parameters

Version 0.1.7
-------------
* Add setting section
* Add problem and algorithm arguments

Version 0.1.6
-------------
* Small fixes

Version 0.1.5
-------------
* Now depends on json_pure for window users

Version 0.1.3
-------------
* Removed spaced in measure type

Version 0.1.1
-------------

### Major Changes (may be backwards incompatible)

* Change XLSX translator to read from a "Variables" spreadsheet instead of "Sensitivity"

### Resolved Issues

* Added check for when weather file is a zip or an epw

* Convert argument values to the right variable types

* Add measure type parsing by reading the inherited class
