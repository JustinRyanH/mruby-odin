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

class StructDef < BaseDef
end

class EnumDef < BaseDef
end

class ParamDef
  def self.valid_param?(decl)
    decl['kind'] == 'ParmVarDecl'
  end

  def self.from_decl(decl)
    nil unless decl['kind'] == 'ParmVarDecl'
    ParamDef.new(decl)
  end

  def initialize(decl)
    @decl = decl
  end

  def name
    decl['name']
  end

  def type
    decl['type']['qualType']
  end

  def to_s
    { name:, type: }.to_s
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
