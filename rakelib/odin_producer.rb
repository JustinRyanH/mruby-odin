# frozen_string_literal: true

require 'erb'

PRIMITIVE_TYPES = {
  'int' => 'c.int',
  'bool' => 'bool',
  '_Boool' => 'bool',
  'char' => 'u8',
  'int8_t' => 'i8',
  'uint8_t' => 'u8',
  'int16_t' => 'i16',
  'uint16_t' => 'u16',
  'int32_t' => 'i32',
  'uint32_t' => 'u32',
  'int64_t' => 'i64',
  'uint64_t' => 'u64',
  'float' => 'f32',
  'double' => 'f64',
  'uintptr_t' => 'u64',
  'intptr_t' => 'i64',
  'size_t' => 'u64',
}.freeze

PRIMITIVE_DEFAULTS = {
  'int' => '0',
  'bool' => 'false',
  'int8_t' => '0',
  'uint8_t' => '0',
  'int16_t' => '0',
  'uint16_t' => '0',
  'int32_t' => '0',
  'uint32_t' => '0',
  'int64_t' => '0',
  'uint64_t' => '0',
  'float' => '0.0',
  'double' => '0.0',
  'uintptr_t' => '0',
  'intptr_t' => '0',
  'size_t' => '0',
}.freeze

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
      StructField.new('field_b', 'bool'),
      StructField.new('field_c', '^f32'),
    ]
    test_struct = OdinStruct.new(name: 'test_struct', fields: struct_fields)

    test_struct.to_s
  end
end
