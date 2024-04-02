require 'rakelib/ast_dump_parser'

class TestAstDumpParser < Minitest::Test
  def test_with_a_perfect_square
    assert ::AstDumpParser.from_clang_dump("{}")

  end
end
