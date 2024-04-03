# frozen_string_literal: true

require 'json'

class BaseDef
  attr_reader :definition

  def initialize(definition)
    @definition = definition
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

  def add_typedef(typedef)
    return unless @name.nil?

    @name = typedef.name
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

class GlobalTypeDef < BaseDef
  def kind
    :global_type
  end

  def id
    definition['id']
  end

  def to_s
    puts definition.keys
    "name #{definition['name']} isReferenced: #{referenced?} inner: #{content} #{content.size}"
  end

  def referenced?
    @referenced ||= definition['isReferenced'] == true
  end

  private

  def content
    # TODO: I need a way to store comments
    definition['inner'].reject { |i| i['kind'] == 'FullComment' }
  end
end

# TODO: Ignore MacPortGuardException
class AstDumpParser
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
    @ordered_ast = @ast_hash['inner'].select { |a| api?(a) }.each { |d| parse(d) }
    puts(kind_map[:enum].map { |e| "id:#{e.id}, n:#{e.name} keys: #{e.values.map(&:name).join(', ')}" })
    kind_map[:global_type].select(&:referenced?).each { |g| puts g }
  end

  private

  attr_reader :ast_hash, :kind_map, :token_map

  def parse(decl)
    case decl['kind']
    when 'RecordDecl'
      StructDef.new(decl).tap do |s|
        @token_map[s.id] = s
        add_to_kind_hash(s)
      end
    when 'EnumDecl'
      EnumDef.new(decl).tap do |e|
        @token_map[e.id] = e
        add_to_kind_hash(e)
      end
    when 'FunctionDecl'
      FuncDef.new(decl).tap do |f|
        @token_map[f.id] = f
        add_to_kind_hash(f)
      end
    when 'TypedefDecl'
      GlobalTypeDef.new(decl).tap do |g|
        @token_map[g.id] = g
        add_to_kind_hash(g)
      end
    else
      raise "Unhandled decl: #{decl['name']}, #{decl['kind']}"
    end
  end

  def api?(decl)
    return true if decl['name']&.include?('mrb')
    return true if decl['kind'] == 'EnumDecl'

    false
  end

  def add_to_kind_hash(ast)
    @kind_map[ast.kind] ||= []
    @kind_map[ast.kind] << ast
  end
end
