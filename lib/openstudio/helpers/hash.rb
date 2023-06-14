# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class Hash
  def deep_find(key)
    key?(key) ? self[key] : values.reduce(nil) { |memo, v| memo ||= v.deep_find(key) if v.respond_to?(:deep_find) }
  end
end
