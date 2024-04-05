# frozen_string_literal: true

require 'erb'

PRIMITIVE_TYPES = {
  'int' => 'c.int',
  'bool' => 'bool',
  '_Bool' => 'bool',
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

class OdinField
  attr_reader :node

  def initialize(node)
    @node = node
  end

  def name
    @name ||= node.name
  end

  def type
    @type ||= begin
      node_type = node.type
      odin_type = PRIMITIVE_TYPES[node_type.without_ptr] || node_type.without_ptr
      odin_type = "^#{odin_type}" if node_type.ptr?
      odin_type
    end
  end
end

StructField = Struct.new(:name, :type)

class OdinStruct
  def initialize(struct_def)
    @struct_def = struct_def
    @struct_name = struct_def.name
    @fields = struct_def.fields.map { |f| OdinField.new(f) }
  end

  def to_s
    template_file = IO.read('rakelib/struct.odin.erb')
    template = ERB.new(template_file, trim_mode: '-')
    template.result(binding)
  end

  private

  def convert_field(field)
    type = field.type
    odin_type = PRIMITIVE_TYPES[type.without_ptr] || type.without_ptr
    odin_type = "^#{odin_type}" if type.ptr?
    StructField.new(field.name, odin_type)
  end
end

class OdinProducter
  attr_reader :ast

  def initialize(ast)
    @ast = ast
  end

  def setup!
    @structs = ast.ordered_ast
                  .select { |a| a.kind == :struct }
                  .map { |a| OdinStruct.new(a) }
    self
  end

  def to_s
    template_file = IO.read('rakelib/file.odin.erb')
    template = ERB.new(template_file, trim_mode: '-')
    template.result(binding)
  end
end
