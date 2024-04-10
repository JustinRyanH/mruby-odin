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
        field_d: rawptr,
        field_e: ^f32,
        field_f: test_example,
      }
    EXP

    assert_equal(expected, out)
  end

  def test_struct_prompt
    struct_example = IO.read('tests/struct_example.json')
    parser = AstDumpParser.from_clang_dump(struct_example, api_id: 'test', file_search_paths: ['tests'])
    parser.parse!

    test_input = StringIO.new
    test_output = StringIO.new

    struct_node = parser.find_struct('test_struct')
    out = OdinStruct.new(struct_node, output: test_output, input: test_input)
    refute(out.problems?)

    struct_node = parser.find_struct('string_struct')
    out = OdinStruct.new(struct_node, output: test_output, input: test_input)
    assert(out.problems?)

    struct_node = parser.find_struct('byte_struct')
    out = OdinStruct.new(struct_node, output: test_output, input: test_input)
    assert(out.problems?)

    struct_node = parser.find_struct('bytes_struct')
    out = OdinStruct.new(struct_node, output: test_output, input: test_input)
    assert(out.problems?)
  end

  def test_odin_file
    skip('until we handle problems, and is able to cache solutions')
    struct_example = IO.read('tests/struct_example.json')
    parser = AstDumpParser.from_clang_dump(struct_example, api_id: 'test', file_search_paths: ['tests'])
    parser.parse!

    producer = OdinProducter.new(parser)
    producer.setup!
    out = producer.to_s

    expected = <<~EXP
      package mruby

      when ODIN_OS == .Darwin {
        foreign import lib "libs/macos/libmruby.a"
      }


      test_example :: struct{}

      test_struct :: struct {
        field_a: c.int,
        field_b: bool,
        field_c: ^f32,
        field_d: rawptr,
        field_e: ^f32,
        field_f: test_example,
      }

    EXP

    assert_equal(expected, out)
  end
end
