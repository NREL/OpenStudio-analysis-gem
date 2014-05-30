OpenStudio Analysis Gem Change Log
==================================

Unreleased
--------------

Version 0.3.0 (not yet on RubyGems)
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

### Major Changes (may be backwards incompatible)

### New Features

### Resolved Issues

* Now depends on json_pure for window users

Version 0.1.3
-------------

### Major Changes (may be backwards incompatible)

### New Features

### Resolved Issues

* Removed spaced in measure type

Version 0.1.1
-------------

### Major Changes (may be backwards incompatible)

* Change XLSX translator to read from a "Variables" spreadsheet instead of "Sensitivity"

### New Features

### Resolved Issues

* Added check for when weather file is a zip or an epw

* Convert argument values to the right variable types

* Add measure type parsing by reading the inherited class


