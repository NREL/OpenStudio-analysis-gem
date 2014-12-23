# add the underscore from rails for snake_casing strings

class String
  def underscore
    gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .downcase
  end

  def snake_case
    gsub(' ', '_').downcase
  end

  def to_bool
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self =~ (/(false|f|no|n|0)$/i)
    fail "invalid value for Boolean: '#{self}'"
  end
end

def typecast_value(variable_type, value, inspect_string = false)
  out_value = nil
  unless value.nil?
    case variable_type.downcase
      when 'double'
        out_value = value.to_f
      when 'integer'
        out_value = value.to_i
      when 'string', 'choice'
        out_value = inspect_string ? value.inspect : value.to_s
      when 'bool', 'boolean'
        if value.downcase == 'true'
          out_value = true
        elsif value.downcase == 'false'
          out_value = false
        else
          fail "Can't cast to a bool from a value of '#{value}' of class '#{value.class}'"
        end
      else
        fail "Unknown variable type of '#{@variable['type']}'"
    end
  end

  out_value
end
