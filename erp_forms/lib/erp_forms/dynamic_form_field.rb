class DynamicFormField
=begin
  Field Options TODO  
  searchable

  Field Types TODO
  special:
  password
  file upload

  complex (for future implementation):
  concatenated
  calculated
  related
=end

#  options = {
#    :fieldLabel => Field label text string
#    :name => Field variable name string
#    :allowblank => required true or false
#    :value => prepopulated default value string
#    :readonly => disabled true or false
#    :maxlength => maxLength integer
#    :width => size integer
#    :validation_regex => regex string
#  }

  ##################
  # SPECIAL FIELDS #
  ##################
  def self.email(options={})
    options[:validation_regex] = "^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$"
    DynamicFormField.basic_field('textfield', options)
  end

  def self.numberfield(options={})
    DynamicFormField.basic_field('numberfield', options)
  end

  def self.datefield(options={})
    DynamicFormField.basic_field('datefield', options)
  end

  def self.timefield(options={})
    DynamicFormField.basic_field('timefield', options)
  end

  def self.yesno(selections=[], options={})
    selections = [['yes', 'Yes'],['no', 'No']]
    DynamicFormField.basic_field('combo', options, selections)
  end

  ################
  # BASIC FIELDS #
  ################  
  # selections is an array of tuples, i.e. [['AL', 'Alabama'],['AK', 'Alaska']] - [value, text]
  def self.combobox(selections=[], options={})
    DynamicFormField.basic_field('combo', options, selections)
  end

  def self.textfield(options={})
    DynamicFormField.basic_field('textfield', options)
  end

  def self.textarea(options={})
    options[:height] = '100' if options[:height].nil? 
    DynamicFormField.basic_field('textarea', options)
  end

  def self.checkbox(options={})
    DynamicFormField.basic_field('checkbox', options)
  end

  def self.hidden(options={})
    DynamicFormField.basic_field('hidden', options)
  end
  
  def self.basic_field(xtype, options={}, selections=[])
    options = DynamicFormField.set_default_field_options(options)

    field = "{
        \"xtype\": \"#{xtype}\",
        \"fieldLabel\": \"#{options[:fieldLabel]}\",
        \"name\": \"#{options[:name]}\",
        \"value\": \"#{options[:value]}\", 
        \"allowBlank\": #{options[:allowblank]},  
        \"readOnly\": #{options[:readonly]},
        \"width\": #{options[:width]},
        \"height\": #{options[:height]},
        \"labelWidth\": #{options[:labelwidth]}"
        
    field += "\"maxLength\": #{options[:maxlength]}," unless options[:maxlength].nil?
    
    if selections and selections != []
      field += ",
        \"store\": #{selections.to_json}"
    end
    
    if options[:validation_regex] and options[:validation_regex] != ''
      field += ",    
        \"validateOnBlur\": true,
        \"validator\": function(v){
          var pattern = /#{options[:validation_regex]}/;
          var regex = new RegExp(pattern);
          return regex.test(v);          
        }"
    end
    
    field += "}"
  end
  
  def self.set_default_field_options(options={})
        
    options[:fieldLabel] = '' if options[:fieldLabel].nil?
    options[:name] = '' if options[:name].nil?
    options[:allowblank] = 'true' if options[:allowblank].nil?
    options[:value] = '' if options[:value].nil?
    options[:readonly] = 'false' if options[:readonly].nil?
    options[:maxlength] = nil if options[:maxlength].nil?
    options[:width] = '"auto"' if options[:width].nil?
    options[:height] = '"auto"' if options[:height].nil?
    options[:validation_regex] = '' if options[:validation_regex].nil?
    options[:labelwidth] = '75' if options[:labelwidth].nil?
    
    options
  end
  
end