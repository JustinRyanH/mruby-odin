# frozen_string_literal: true

require 'erb'

StructField = Struct.new(:name, :type)

class OdinStruct
  def initialize(name:, fields: [])
    @struct_name = name
    @fields = fields
  end

  def to_s
    template_file = IO.read('rakelib/struct.odin.erb')
    template = ERB.new(template_file, trim_mode: '-')
    template.result(binding)
  end
end

class OdinProducter
  def self.output_struct(_node)
    struct_fields = [
      StructField.new('field_a', 'c.int'),
      StructField.new('field_b', 'bool')
    ]
    test_struct = OdinStruct.new(name: 'test_struct', fields: struct_fields)

    test_struct.to_s
  end
end
