class Hash
  def deep_find(key)
    key?(key) ? self[key] : values.reduce(nil) { |memo, v| memo ||= v.deep_find(key) if v.respond_to?(:deep_find) }
  end
end
