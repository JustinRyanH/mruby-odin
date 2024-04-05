# frozen_string_literal: true

require 'rakelib/ast_dump_parser'
require 'rakelib/odin_producer'

class TestOdinProducor < Minitest::Test
  def test_output_struct
    struct_example = IO.read('tests/struct_example.json')
    parser = AstDumpParser.from_clang_dump(struct_example, api_id: 'test', file_search_paths: ['tests'])
    parser.parse!

    struct_node = parser.find_struct('test_struct')
    out = OdinStruct.new(struct_node).to_s

    expected = <<~EXP
      test_struct :: struct {
        field_a: c.int,
        field_b: bool,
        field_c: ^f32,
      }
    EXP

    assert_equal(expected, out)
  end

  def test_odin_file
    struct_example = IO.read('tests/struct_example.json')
    parser = AstDumpParser.from_clang_dump(struct_example, api_id: 'test', file_search_paths: ['tests'])
    parser.parse!

    producer = OdinProducter.new(parser)
    producer.setup!
    out = producer.to_s

    expected = <<~EXP
      package mrby

      when ODIN_OS == .Darwin {
        foreign import lib "libs/macos/libmruby.a"
      }


      test_struct :: struct {
        field_a: c.int,
        field_b: bool,
        field_c: ^f32,
      }

    EXP

    assert_equal(expected, out)
  end
end
