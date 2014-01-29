# add the underscore from rails for snake_casing strings

class String
  def underscore
    self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr("-", "_").
        downcase
  end
  
  def snake_case
    self.gsub(" ", "_").downcase
  end
end
                     
