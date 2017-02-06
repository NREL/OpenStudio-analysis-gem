OpenStudio Analysis Gem Change Log
==================================

Version 1.0.0.rc11 (Unreleased)
------------------
* Default path to ServerApi logfile to ~/os_server_api.log. This can be overridden by setting the log_path options key in the initializer.
* Fix get_datapoint_status for new version of API where data_points are under analysis

Version 1.0.0.rc10
------------------
* Fix boolean data type in datapoints translator
* Allow __skip__ variable in datapoints translator

Version 1.0.0.rc9
-----------------
* Fix bug in batch datapoints to look for outputs_json, not outputs when importing the definition of the outputs JSON file.

Version 1.0.0.rc8
-----------------
* Allow "None" as an argument in batch datapoints. This will allow the measure to be added without setting any of the arguments. Useful for adding Reporting Measures to the workflow.

Version 1.0.0.rc7
-----------------
* Use more recent version of BCL gem for underscoring strings

Version 1.0.0.pre.rc6
---------------------
* When creating OSWs from batch datapoints, set the default run_directory to ./run

Version 1.0.0.pre.rc5
---------------------
* fix get_datapoint method. show_full is no longer a valid endpoint in the new server code 

Version 1.0.0.pre.rc4
---------------------
* Change seed_model to seed_file in OSWs generated from the translator
* Add more unit tests

Version 1.0.0.pre.rc3
---------------------
* Catch null arguments when translating from OSA/OSD to OSW

Version 1.0.0.pre.rc2
--------------------------------
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

Version 1.0.0-pat2
------------------------------
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
