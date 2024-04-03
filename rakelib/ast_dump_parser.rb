# frozen_string_literal: true

require 'json'

class BaseDef
  attr_reader :definition

  def initialize(definition)
    @definition = definition
  end

  def parse
    self
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
      raise "Field Definition has no type #{definition}" if type_def.nil?

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
    { name:, kind:, type: type.to_s }.to_s
  end
end

class StructDef < BaseDef
  attr_reader :name

  def parse
    @name = definition['name']
    self
  end

  def kind
    :struct
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
    { name:, kind:, fields: "[#{fields.map(&:to_s).join(', ')}]" }.to_s
  end
end

class EnumDef < BaseDef
  attr_reader :name

  def parse
    @name = definition['name']
    self
  end

  def kind
    :enum
  end

  def to_s
    { name:, kind: }.to_s
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

  def name
    decl['name']
  end

  def type
    @type ||= TypeDef.new(decl['type'])
  end

  def to_s
    { name:, type: type.to_s }.to_s
  end

  private

  attr_reader :decl
end

class FuncDef < BaseDef
  attr_reader :name, :kind, :params

  def parse
    @name = definition['name']
    @kind = 'func'
    @params ||= []
    load_params!
    self
  end

  def to_s
    {
      name:,
      kind:,
      params: "[#{params.map(&:to_s).join(', ')}]"
    }.to_s
  end

  private

  def load_params!
    values = definition['inner']
    return unless values

    values.each do |v|
      ## TODO: investigate each of these
      next if v['kind'] == 'CompoundStmt'
      next if v['kind'] == 'FullComment'
      next if v['kind'] == 'C11NoReturnAttr'

      unless ParamDef.valid_param?(v)
        puts "\nParam(#{v['name'] || v['kind']}) was ignored\n"
        next
      end

      @params << ParamDef.from_decl(v)
    end
  end
end

class AstDumpParser
  # @param [String] dump - the raw output from `clang -ast-dump=json`
  def self.from_clang_dump(dump)
    new(JSON.parse(dump))
  end

  def initialize(ast_hash)
    @ast_hash = ast_hash
  end

  def parse!
    definitions = @ast_hash['inner'].select { |a| api?(a) }.map { |d| parse(d) }
    definitions.each do |d|
      puts d
    end
  end

  def parse(decl)
    case decl['kind']
    when 'RecordDecl'
      StructDef.new(decl).parse
    when 'EnumDecl'
      EnumDef.new(decl).parse
    when 'FunctionDecl'
      FuncDef.new(decl).parse
    end
  end

  def api?(decl)
    return true if decl['name']&.include?('mrb')
    return true if decl['kind'] == 'EnumDecl'

    false
  end
end
