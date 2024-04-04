# frozen_string_literal: true

require 'json'

class AstLocation
  attr_reader :loc

  def initialize(location)
    @loc = location
  end

  def line
    @line ||= loc['line']
  end

  def column
    @column ||= loc['col']
  end

  def file
    @file ||= loc.dig('includedFrom', 'file')
  end

  def to_s
    { line:, column:, file: }.to_s
  end
end

class BaseDef
  attr_reader :definition

  def initialize(definition)
    @definition = definition
  end

  def location
    @location ||= AstLocation.new(definition['loc'])
  end
end

class TypeDef
  def initialize(type_def)
    @type_def = type_def
  end

  def to_s
    as_str
  end

  private

  attr_reader :type_def

  def as_str
    @as_str ||= begin
      return type_def if type_def.is_a? String
      return '' if type_def.nil?

      type_def['qualType']
    end
  end
end

class StructFieldDef
  attr_reader :definition

  def self.valid_field?(decl)
    return false unless decl['kind'] == 'FieldDecl'

    true
  end

  def self.from_decl(decl)
    return nil unless StructFieldDef.valid_field?(decl)

    new(decl)
  end

  def initialize(definition)
    @definition = definition
  end

  def id
    @id ||= definition['id']
  end

  def name
    @name ||= definition['name']
  end

  def kind
    :struct_field
  end

  def type
    @type ||= TypeDef.new(definition['type'])
  end

  def to_s
    { id:, name:, kind:, type: type.to_s }.to_s
  end
end

class StructDef < BaseDef
  def name
    @name ||= definition['name']
  end

  def kind
    :struct
  end

  def id
    @id ||= definition['id']
  end

  def fields
    @fields ||= [].tap do |f|
      definition.fetch('inner', []).each do |maybe_field|
        next unless StructFieldDef.valid_field?(maybe_field)

        f << StructFieldDef.from_decl(maybe_field)
      end
    end
  end

  def add_typedef(typedef)
    @typedef = typedef
    @name = typedef.name if @name.nil?
  end

  def to_s
    { id:, name:, kind:, fields: "[#{fields.map(&:to_s).join(', ')}]" }.to_s
  end
end

class EnumEntry
  attr_reader :definition

  def initialize(definition)
    @definition = definition
    @typedef = nil
  end

  def name
    @name ||= definition['name']
  end

  def type
    @type = TypeDef.new(definition['type'])
  end

  def value
    @value ||= query_set_value
  end

  def to_s
    { name:, type: type.to_s, value: }.to_s
  end

  private

  def query_set_value
    return nil unless definition.key?('inner')
    raise 'Enum should not have more than one value' unless definition['inner'].size == 1

    set_value = definition['inner'].first
    raise 'Set Value should have a set value' unless set_value.key?('inner')
    raise 'Enum should not have more than one value' unless set_value['inner'].size == 1

    set_value['inner'].first['value']
  end
end

class EnumDef < BaseDef
  def id
    @id ||= definition['id']
  end

  def kind
    :enum
  end

  def name
    @name ||= definition['name']
  end

  def add_typedef(typedef)
    @typedef = typedef
    @name = typedef.name if @name.nil?
  end

  def values
    @values ||= [].tap do |v|
      definition['inner'].each { |i| v << EnumEntry.new(i) }
    end
  end

  def to_s
    { id:, name:, kind:, values: "[#{values.map(&:to_s).join(', ')}]" }.to_s
  end
end

class ParamDef
  def self.valid_param?(decl)
    decl['kind'] == 'ParmVarDecl'
  end

  def self.from_decl(decl)
    nil unless ParamDef.valid_param?(decl)
    ParamDef.new(decl)
  end

  def initialize(decl)
    @decl = decl
  end

  def id
    @id ||= decl['id']
  end

  def name
    decl['name']
  end

  def type
    @type ||= TypeDef.new(decl['type'])
  end

  def to_s
    { id:, name:, type: type.to_s }.to_s
  end

  private

  attr_reader :decl
end

class FuncDef < BaseDef
  def params
    @params ||= load_params.compact
  end

  def name
    @name ||= definition['name']
  end

  def kind
    :func
  end

  def id
    @id ||= definition['id']
  end

  def to_s
    {
      id:,
      name:,
      kind:,
      params: "[#{params.map(&:to_s).join(', ')}]"
    }.to_s
  end

  private

  def load_params
    values = definition['inner']
    return [] unless values

    values.map { |v| parse_param_value(v) }
  end

  def parse_param_value(param_value)
    ## TODO: investigate each of these
    return nil if param_value['kind'] == 'CompoundStmt'
    return nil if param_value['kind'] == 'FullComment'
    return nil if param_value['kind'] == 'C11NoReturnAttr'

    unless ParamDef.valid_param?(param_value)
      puts "\nParam(#{param_value['name'] || param_value['kind']}) was ignored\n"
      return nil
    end

    ParamDef.from_decl(param_value)
  end
end

class TagOwner < BaseDef
  def kind
    :owner_tag
  end

  def id
    @id ||= definition['id']
  end

  def name
    @name ||= definition['name']
  end

  def target_kind
    @target_kind ||= case definition['kind']
                     when 'EnumDecl'
                       :enum
                     when 'RecordDecl'
                       :struct
                     else
                       raise "#{definition['kind']} unhandled"
                     end
  end

  def to_s
    { id:, kind:, name:, target_kind: }.to_s
  end
end

# TODO: Handle Aliases, Function Typedef
class GlobalTypeDef < BaseDef
  def kind
    :global_type
  end

  def id
    @id ||= definition['id']
  end

  def name
    @name ||= definition['name']
  end

  def to_s
    {
      id:,
      kind:,
      content_type:,
      is_referenced: referenced?,
      owner: owner.to_s
    }.to_s
  end

  def referenced?
    @referenced ||= definition['isReferenced'] == true
  end

  def content_type
    case content_solo['kind']
    when 'ElaboratedType'
      :elaborated
    when 'PointerType'
      :pointer
    when 'TypedefType'
      :typedef
    when 'BuiltinType'
      :builtin
    when 'ParenType'
      :paren
    when 'RecordType'
      :record
    when 'ConstantArrayType'
      :array
    else
      puts content_solo
      raise "Unhandled Typedef #{content_solo['kind']}"
    end
  end

  def owner
    @owner ||= content_solo.key?('ownedTagDecl') ? TagOwner.new(content_solo['ownedTagDecl']) : nil
  end

  def target_type
    owner&.target_kind
  end

  private

  def content_solo
    raise 'GlobalDef should have only one instance of content' if content.size > 1

    content.first
  end

  def content
    # TODO: I need a way to store comments
    definition['inner'].reject { |i| i['kind'] == 'FullComment' }
  end
end

class AstDumpParser
  attr_reader :ast_hash, :kind_map, :token_map, :ordered_ast

  # @param [String] dump - the raw output from `clang -ast-dump=json`
  def self.from_clang_dump(dump)
    new(JSON.parse(dump))
  end

  def initialize(ast_hash)
    @ast_hash = ast_hash
    @token_map = {}
    @kind_map = {}
    @ordered_ast = []
  end

  def parse!
    @ast_hash['inner'].each { |d| parse(d) }

    attach_types
    cleanup_external_tokens
  end

  def find_struct(name)
    kind_map[:struct].find { |s| s.name == name }
  end

  private

  def parse(decl)
    case decl['kind']
    when 'RecordDecl'
      StructDef.new(decl).tap do |s|
        @token_map[s.id] = s
        add_to_kind_hash(s)
        @ordered_ast << s
      end
    when 'EnumDecl'
      EnumDef.new(decl).tap do |e|
        @token_map[e.id] = e
        add_to_kind_hash(e)
        @ordered_ast << e
      end
    when 'FunctionDecl'
      FuncDef.new(decl).tap do |f|
        @token_map[f.id] = f
        add_to_kind_hash(f)
        @ordered_ast << f
      end
    when 'TypedefDecl'
      GlobalTypeDef.new(decl).tap do |g|
        @token_map[g.id] = g
        add_to_kind_hash(g)
        @ordered_ast << g
      end
    when 'VarDecl', 'StaticAssertDecl'
      # I don't forsee myself needing this decl
      nil
    else
      raise "Unhandled decl: #{decl['name']}, #{decl['kind']}"
    end
  end

  def attach_types
    kind_map[:global_type]
      .select { |g| g.content_type == :elaborated }
      .select(&:owner)
      .each do |g|
        target_id = g.owner.id

        owner = @token_map[target_id]
        owner.add_typedef(g)
      end
  end

  def cleanup_external_tokens
    to_delete = @ordered_ast.reject { |ast| ast.location&.file&.include?('mruby') }
    to_delete.each do |node|
      @token_map.delete(node.id)
      @kind_map[node.kind].reject! { |k| k.id == node.id }
      @ordered_ast.reject! { |o| o.id == node.id }
    end
  end

  def add_to_kind_hash(ast)
    @kind_map[ast.kind] ||= []
    @kind_map[ast.kind] << ast
  end
end
