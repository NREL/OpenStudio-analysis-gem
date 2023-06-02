# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rexml/document'

def parse_measure_xml(measure_xml_filename)
  measure_hash = {}
  xml_to_parse = File.open(measure_xml_filename)
  xml_root = REXML::Document.new(xml_to_parse).root

  # pull out some information
  measure_hash[:classname] = xml_root.elements['//measure/class_name'].text
  measure_hash[:name] = xml_root.elements['//measure/name'].text
  measure_hash[:display_name] = xml_root.elements['//measure/display_name'].text
  measure_hash[:display_name_titleized] = measure_hash[:name].titleize
  measure_hash[:measure_type] = xml_root.elements['//measure/attributes/attribute[name="Measure Type"]/value'].text
  measure_hash[:description] = xml_root.elements['//measure/description'].text
  measure_hash[:modeler_description] = xml_root.elements['//measure/modeler_description'].text
  measure_hash[:uid] = xml_root.elements['//measure/uid'].text
  measure_hash[:version_id] = xml_root.elements['//measure/version_id'].text
  measure_hash[:arguments] = []

  REXML::XPath.each(xml_root, '//measure/arguments/argument') do |arg|
    measure_hash[:arguments] << {
      name: arg.elements['name']&.text,
      display_name: arg.elements['display_name']&.text,
      variable_type: arg.elements['type']&.text.downcase,
      default_value: arg.elements['default_value']&.text,
      units: arg.elements['units']&.text || ''
    }
  end

  measure_hash
end
