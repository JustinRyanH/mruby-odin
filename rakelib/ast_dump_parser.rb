require 'json'

class AstDumpParser
  # @param [String] dump - the raw output from `clang -ast-dump=json`
  def self.from_clang_dump(dump) 
    new(JSON.parse(dump))
  end


  def initialize(ast_hash)
    @ast_hash = ast_hash
  end
end
