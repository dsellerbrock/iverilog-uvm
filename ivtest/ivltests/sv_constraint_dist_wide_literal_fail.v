// Strict negative: constraint IR value atoms currently carry at most 64 bits.
class dist_wide_literal_bad;
  rand bit [63:0] value;
  constraint bad_c { value dist {128'h0000000000000001_0000000000000000 := 1}; }
endclass

package dist_wide_constant_pkg;
  localparam bit [127:0] BIG = 128'h0000000000000001_0000000000000000;
endpackage

class dist_wide_parameter_bad;
  rand bit [63:0] value;
  constraint bad_c {
    value dist {dist_wide_constant_pkg::BIG :/ 1};
  }
endclass

// Even a high-zero branch cannot make a wider randomized property safe: the
// current runtime model-transfer interface carries only uint64_t values.
class dist_wide_storage_bad;
  rand bit [127:0] value;
  constraint bad_c { value dist {128'd1 :/ 1}; }
endclass

class dist_wide_state_cfg;
  bit [127:0] endpoint = 128'd1;
endclass

// Nested object state uses the r: runtime-storage path rather than a solver
// property, but it has the same uint64 transfer boundary.
class dist_wide_nested_state_bad;
  rand bit value;
  dist_wide_state_cfg cfg = new;
  constraint bad_c { value dist {cfg.endpoint :/ 1, 0 :/ 1}; }
endclass

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
  dist_wide_literal_bad item;
  dist_wide_parameter_bad parameter_item;
  dist_wide_storage_bad wide_storage_item;
  dist_wide_nested_state_bad wide_nested_state_item;
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

  // An inline caller-value slot uses v: storage and must retain the same loud
  // boundary instead of truncating the 128-bit actual to a 32-bit token.
  bit scope_value;
  bit [127:0] caller_wide;
  initial void'(std::randomize(scope_value) with {
    scope_value dist {caller_wide :/ 1, 0 :/ 1};
  });

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
