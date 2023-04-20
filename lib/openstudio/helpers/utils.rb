# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2023, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
