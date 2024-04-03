# frozen_string_literal: true

require 'rakelib/ast_dump_parser'

class TestAstDumpParser < Minitest::Test
  def test_with_a_perfect_square
    refute_nil ::AstDumpParser.from_clang_dump('{}')
  end

  def test_global_types
    file = File.open('tests/main_c_dump.json')
    parser = ::AstDumpParser.from_clang_dump(file.read)
    refute_nil file.size
    refute_nil parser

    parser.parse!
  end
end
