
# Typecast Variable Values by a string.
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
        # Check if the value is already a boolean
        if !!value == value
          out_value = value
        else
          if value.casecmp('true').zero?
            out_value = true
          elsif value.casecmp('false').zero?
            out_value = false
          else
            raise "Can't cast to a bool from a value of '#{value}' of class '#{value.class}'"
          end
        end
      else
        raise "Unknown variable type of '#{@variable['type']}'"
    end
  end

  out_value
end
