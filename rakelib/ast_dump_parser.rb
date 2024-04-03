# frozen_string_literal: true

require 'json'

class AstDumpParser
  # @param [String] dump - the raw output from `clang -ast-dump=json`
  def self.from_clang_dump(dump)
    new(JSON.parse(dump))
  end

  def initialize(ast_hash)
    @ast_hash = ast_hash
  end

  def parse!
    @ast_hash['inner'].select { |a| api?(a) }.map { |d| parse(d) }
  end

  def parse(decl)
    case decl['kind']
    when 'RecordDecl'
      puts "Struct #{decl['name']}"
    when 'EnumDecl'
      puts "Enum #{decl['name']}"
    when 'FunctionDecl'
      puts "Func #{decl['name']}"
    end
  end

  def parse_struct(decl)
  end

  def api?(decl)
    return true if decl['name']&.include?('mrb')
    return true if decl['kind'] == 'EnumDecl'

    false
  end
end
