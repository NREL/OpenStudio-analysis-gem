

###### (Automatically generated documentation)

# Add Monthly JSON Utility Data

## Description
Add Monthly JSON Utility Data

## Modeler Description
Add Monthly JSON Formatted Utility Data to OSM as a UtilityBill Object

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Path to JSON Data in the Server.
Path to JSON Data in the Server. calibration_data is directory name of uploaded files.
**Name:** json,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Variable name
Name of the Utility Bill Object.  For Calibration Report use Electric Bill or Gas Bill
**Name:** variable_name,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Fuel Type
Fuel Type
**Name:** fuel_type,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Consumption Unit
Consumption Unit (usually kWh or therms)
**Name:** consumption_unit,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### data key name in JSON
data key name in JSON
**Name:** data_key_name,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Start date
Start date format %Y%m%dT%H%M%S with Hour Min Sec optional
**Name:** start_date,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### End date
End date format %Y%m%dT%H%M%S with Hour Min Sec optional
**Name:** end_date,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### remove all existing Utility Bill data objects from model
remove all existing Utility Bill data objects from model
**Name:** remove_existing_data,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Set RunPeriod Object in model to use start and end dates
Set RunPeriod Object in model to use start and end dates.  Only needed once if multiple copies of measure being used.
**Name:** set_runperiod,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




