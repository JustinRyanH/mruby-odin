require 'rakelib/ast_dump_parser'

class TestAstDumpParser < Minitest::Test
  def test_with_a_perfect_square
    assert ::AstDumpParser.from_clang_dump("{}")
  end

  def test_inner
    file = File.open('tests/main_c_dump.json')
    parser = ::AstDumpParser.from_clang_dump(file.read)
    refute_nil file.size
    refute_nil parser


  end
end
