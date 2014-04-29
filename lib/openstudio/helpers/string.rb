# add the underscore from rails for snake_casing strings

class String
  def underscore
    gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr('-', '_').
        downcase
  end

  def snake_case
    gsub(' ', '_').downcase
  end

  def to_bool
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self =~ (/(false|f|no|n|0)$/i)
    fail ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end
