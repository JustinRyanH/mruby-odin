# frozen_string_literal: true

class OdinProducter
  def self.output_struct(_node)
    <<-DEMO
    test_struct :: struct {
      field_a: c.int,
      field_b: bool,
    }
    DEMO
  end
end
