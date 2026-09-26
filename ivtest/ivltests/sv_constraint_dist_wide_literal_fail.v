// Strict negative: dist expressions that need IEEE 11.8.2 top-down context
// propagation stay loudly unsupported. Wide dist values are supported; see
// sv_randomize_wide_dist_assoc.v.
// Nested arithmetic needs IEEE 11.8.2 top-down context propagation. Until the
// compact solver IR can replay the inner node in that context, reject it.
class dist_nested_arithmetic_bad;
  rand bit signed [3:0] a;
  rand bit signed [3:0] b;
  rand bit [7:0] u;
  constraint bad_c { ((a + b) + u) dist {8'd14 :/ 1}; }
endclass

class dist_flat_signed_context_bad;
  rand bit signed [3:0] a;
  rand bit signed [3:0] b;
  constraint zero_c { b == 0; }
  constraint bad_c { (a + b) dist {8'd14 :/ 1}; }
endclass

class dist_nested_weight_bad;
  rand bit value;
  bit signed [3:0] a;
  bit signed [3:0] b;
  bit [7:0] u;
  constraint bad_c {
    value dist {0 :/ ((a + b) + u), 1 :/ 1};
  }
endclass

// The symmetric item-side case also needs the unsigned subject comparison
// context propagated through the signed add. Until the compact IR can carry
// that context downward, accepting this would silently constrain value to 30
// instead of the IEEE result 14.
class dist_flat_signed_item_context_bad;
  rand bit [7:0] value;
  bit signed [3:0] a;
  bit signed [3:0] b;
  constraint bad_c { value dist {(a + b) :/ 1}; }
endclass

class dist_flat_bitwise_context_bad;
  rand bit signed [3:0] a;
  rand bit [7:0] mask;
  constraint fixed_c { a == -2; mask == 8'hff; }
  constraint bad_c { (a & mask) dist {8'd14 :/ 1}; }
endclass

class dist_power_context_bad;
  rand bit [7:0] value;
  constraint bad_c { (value ** 2) dist {8'd4 :/ 1}; }
endclass

class dist_widened_unary_minus_bad;
  rand bit [3:0] value;
  constraint fixed_c { value == 1; }
  constraint bad_c { (-value) dist {8'hff :/ 1}; }
endclass

class dist_widened_bitwise_not_bad;
  rand bit [3:0] value;
  constraint fixed_c { value == 0; }
  constraint bad_c { (~value) dist {8'hff :/ 1}; }
endclass

class dist_widened_unsigned_sub_bad;
  rand bit [3:0] value;
  constraint fixed_c { value == 0; }
  constraint bad_c { (value - 1) dist {8'hff :/ 1}; }
endclass

class dist_widened_signed_div_bad;
  rand bit signed [3:0] numerator;
  rand bit signed [3:0] divisor;
  constraint fixed_c { numerator == -8; divisor == -1; }
  constraint bad_c { (numerator / divisor) dist {8'sd8 :/ 1}; }
endclass

class dist_ternary_context_bad;
  rand bit select;
  rand bit signed [3:0] a;
  rand bit [7:0] b;
  constraint bad_c { (select ? a : b) dist {8'd14 :/ 1}; }
endclass

class dist_nested_bitwise_context_bad;
  rand bit [3:0] a;
  rand bit [7:0] u;
  constraint bad_c { ((~a) + u) dist {8'd255 :/ 1}; }
endclass

class dist_fill_subject_bad;
  constraint bad_c { '1 dist {1 :/ 1}; }
endclass

module test;
  dist_nested_arithmetic_bad nested_item;
  dist_flat_signed_context_bad flat_context_item;
  dist_nested_weight_bad nested_weight_item;
  dist_flat_signed_item_context_bad flat_item_context_item;
  dist_flat_bitwise_context_bad flat_bitwise_context_item;
  dist_power_context_bad power_context_item;
  dist_widened_unary_minus_bad widened_unary_item;
  dist_widened_bitwise_not_bad widened_bnot_item;
  dist_widened_unsigned_sub_bad widened_sub_item;
  dist_widened_signed_div_bad widened_div_item;
  dist_ternary_context_bad ternary_item;
  dist_nested_bitwise_context_bad nested_bnot_item;
  dist_fill_subject_bad fill_subject_item;

  // Inline caller slots are initially emitted as v:N:32 placeholders. Their
  // real signed/unsigned widths must be applied before dist's IEEE 11.8.2
  // safety validation, not afterward when the unsafe shape was already
  // accepted.
  bit [7:0] inline_value;
  bit signed [3:0] caller_signed_a;
  bit signed [3:0] caller_signed_b;
  initial void'(std::randomize(inline_value) with {
    inline_value dist {(caller_signed_a + caller_signed_b) :/ 1};
  });
endmodule
