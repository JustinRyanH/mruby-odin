# frozen_string_literal: true

require 'rakelib/ast_dump_parser'

class TestAstDumpParser < Minitest::Test
  def test_with_a_perfect_square
    refute_nil ::AstDumpParser.from_clang_dump('{}')
  end

  def test_global_types
    file = File.open('tests/main_c_dump.json')
    parser = ::AstDumpParser.from_clang_dump(file.read)

    parser.parse!

    assert_equal(%i[enum func global_type struct].sort, parser.kind_map.keys.sort)
  end

  def test_mrb_state
    file = File.open('tests/main_c_dump.json')
    parser = ::AstDumpParser.from_clang_dump(file.read)

    parser.parse!
    struct = parser.find_struct('mrb_state')

    refute_nil struct
    refute_empty struct.fields
  end
end
