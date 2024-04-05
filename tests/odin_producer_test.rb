# frozen_string_literal: true

require 'rakelib/ast_dump_parser'
require 'rakelib/odin_producer'

class TestOdinProducor < Minitest::Test
  def test_output_struct
    struct_example = IO.read('tests/struct_example.json')
    parser = AstDumpParser.from_clang_dump(struct_example, api_id: 'test', file_search_paths: ['tests'])
    parser.parse!

    struct_node = parser.find_struct('test_struct')
    out = OdinProducter.output_struct(struct_node)

    expected = <<~EXP
      test_struct :: struct {
        field_a: c.int,
        field_b: bool,
        field_c: ^f32,
      }
    EXP

    assert_equal(expected, out)
  end
end
