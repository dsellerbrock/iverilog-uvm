// IEEE 1800-2023 18.5.3 (2017 18.5.4): the subject of a dist constraint is
// an integral expression. A relational expression is a one-bit integral
// value even
// though the Z3 API represents it with Bool sort. This is the exact shape
// used by OpenTitan HMAC for digest-size and key-length selection.
class dist_boolean_subject;
  rand bit [3:0] digest_size;
  constraint digest_size_c {
    $countones(digest_size) == 1 dist {
      1 :/ 4,
      0 :/ 1
    };
  }
endclass

// OpenTitan also uses $countones as the complete dist subject, both on a
// packed leaf and on its self-determined bitwise complement.
class dist_countones_root_subject;
  rand bit [3:0] value;
  constraint value_c { $countones(value) dist {1 :/ 1}; }
endclass

class dist_countones_bnot_subject;
  rand bit [3:0] value;
  constraint value_c { $countones(~value) dist {1 :/ 1}; }
endclass

class dist_terminal_comparison_subject;
  rand bit [7:0] key_version;
  bit [7:0] max_key_version;
  constraint value_c {
    (key_version == max_key_version) dist {0 :/ 3, 1 :/ 1};
  }
endclass

// Arithmetic ASTs can be physically wider than their SystemVerilog
// self-determined width. Exact pinning must coerce the physical AST just as
// the hard dist branch does instead of extending by the semantic-width delta.
class dist_arithmetic_subject;
  rand bit [3:0] a;
  rand bit [3:0] b;
  constraint sum_c {
    (a + b) dist {
      2 :/ 1,
      17 :/ 1
    };
  }
endclass

// Binary arithmetic is signed only when both operands are signed. Preserve
// that result type on the solver AST so a signed expression can use a range
// that crosses zero without being reinterpreted in unsigned order.
class dist_signed_arithmetic_subject;
  rand bit signed [3:0] a;
  rand bit signed [3:0] b;
  constraint zero_b_c { b == 0; }
  constraint sum_c { (a + b) dist {[-2:2] := 1, 3 := 1}; }
endclass

// One unsigned operand makes binary arithmetic unsigned and requires both
// narrower operands to zero-extend. The signed 4-bit pattern 4'he is 14 in
// this expression context.
class dist_mixed_arithmetic_subject;
  rand bit signed [3:0] signed_value;
  rand bit [7:0] unsigned_zero;
  constraint zero_c { unsigned_zero == 0; }
  constraint sum_c {
    (signed_value + unsigned_zero) dist {8'd14 :/ 1};
  }
endclass

class dist_multiply_subject;
  rand bit [3:0] a;
  rand bit [3:0] b;
  constraint product_c { (a * b) dist {8'd100 :/ 1}; }
endclass

class dist_signed_subtract_subject;
  rand bit signed [3:0] a;
  rand bit signed [3:0] b;
  constraint zero_c { b == 0; }
  constraint difference_c { (a - b) dist {[-2:2] := 1, 3 := 1}; }
endclass

class dist_unsigned_divide_subject;
  rand bit [7:0] value;
  constraint quotient_c { (value / 8'd2) dist {8'd3 :/ 1}; }
endclass

class dist_signed_modulus_subject;
  rand bit signed [3:0] value;
  constraint remainder_c { (value % 4'sd3) dist {-4'sd2 :/ 1}; }
endclass

// Active OpenTitan shapes that remain inside the flat expression boundary:
// AES uses a modulus subject and several constraints use unary bitwise not.
class dist_modulus_subject;
  rand bit [7:0] value;
  constraint value_c { (value % 16) dist {0 :/ 1}; }
endclass

class dist_bitwise_not_subject;
  rand bit [3:0] value;
  constraint value_c { (~value) dist {4'h5 :/ 1}; }
endclass

// Unbased unsized fill literals take the comparison width supplied by the
// dist subject. These are the exact terminal and complemented-subject forms
// used by OpenTitan alert/entropy sequences.
class dist_fill_terminal_subject;
  rand bit [3:0] value;
  constraint value_c {
    value dist {'1 :/ 9, [0:('1 - 1'b1)] :/ 1};
  }
endclass

class dist_fill_bnot_subject;
  rand bit [31:0] value;
  constraint fixed_c { value == 32'd1; }
  constraint value_c {
    (~value) dist {'1 :/ 9, [0:('1 - 1'b1)] :/ 1};
  }
endclass

// OTP DAI uses a fixed part-select plus alignment bits as its subject and a
// resolved offset through an all-ones endpoint.
class dist_concat_fill_subject;
  localparam int TL_AW = 8;
  localparam int VendorTestOffset = 100;
  rand bit [TL_AW-1:0] dai_addr;
  constraint fixed_c { dai_addr == 8'hfc; }
  constraint value_c {
    {dai_addr[TL_AW-1:2], 2'b0}
      dist {[VendorTestOffset:'1] :/ 1};
  }
endclass

class dist_concat_terminal_subject;
  rand bit [1:0] boot_req_mode;
  rand bit [1:0] auto_req_mode;
  constraint value_c {
    {boot_req_mode, auto_req_mode} dist {4'b1001 :/ 1};
  }
endclass

class dist_repeat_concat_endpoint;
  localparam int OTP_ADDR_WIDTH = 16;
  rand bit [OTP_ADDR_WIDTH-1:0] address;
  constraint value_c {
    address dist {{OTP_ADDR_WIDTH{1'b1}} :/ 1};
  }
endclass

class dist_bit_select_subject;
  rand bit [3:0] periph_to_mio_oe;
  rand bit [1:0] index;
  constraint index_c { index == 2; }
  constraint value_c {
    periph_to_mio_oe[index] dist {1 :/ 0, 0 :/ 1};
  }
endclass

// Ibex selects a weight through equal-type nested state ternaries.
class dist_ternary_weight;
  bit invalidate;
  bit enable;
  rand bit value;
  constraint value_c {
    value dist {
      0 :/ (invalidate ? 1000 : enable ? 0 : 1),
      1 :/ (invalidate ? 0 : enable ? 1000 : 0)
    };
  }
endclass


class dist_nested_sub_weight;
  int unsigned boot_req_mode_pct;
  int unsigned auto_req_mode_pct;
  rand bit value;
  constraint value_c {
    value dist {
      0 :/ (100 - boot_req_mode_pct - auto_req_mode_pct),
      1 :/ 1
    };
  }
endclass

class dist_nested_add_sub_weight;
  int rx_only_weight;
  int dummy_weight;
  rand bit value;
  constraint value_c {
    value dist {
      0 :/ (100 - (rx_only_weight + dummy_weight)),
      1 :/ 1
    };
  }
endclass

// CSRNG feeds a same-width uint subtraction through division before the
// MUBI macro multiplies it by MAX-1. The subtraction must wrap to 32 bits
// before division; dividing the solver's extra carry bit gives a different
// result when the subtraction underflows.
class dist_nested_divide_weight;
  int unsigned percentage;
  rand bit value;
  constraint value_c {
    value dist {
      0 :/ (((100 - percentage) / 2) * 14),
      1 :/ 0
    };
  }
endclass

// The utility MUBI macros use constant min/max ternaries, shift-derived MAX,
// and live signed weights. This mirrors the ordinary expansion; the 16-bit
// helper below also preserves the source macro's unusual live MAX argument.
class dist_mubi_macro_shape;
  localparam bit [3:0] TRUE_VALUE = 4'ha;
  localparam bit [3:0] FALSE_VALUE = 4'h5;
  localparam int MAX_VALUE = (1 << 4) - 1;
  int true_weight;
  int false_weight;
  int other_weight;
  rand bit [3:0] value;
  constraint value_c {
    value dist {
      TRUE_VALUE :/ (true_weight * (MAX_VALUE - 1)),
      FALSE_VALUE :/ (false_weight * (MAX_VALUE - 1)),
      [0:(((TRUE_VALUE < FALSE_VALUE) ? TRUE_VALUE : FALSE_VALUE) - 1)]
        :/ other_weight,
      [(((TRUE_VALUE < FALSE_VALUE) ? TRUE_VALUE : FALSE_VALUE) + 1):
       (((TRUE_VALUE < FALSE_VALUE) ? FALSE_VALUE : TRUE_VALUE) - 1)]
        :/ other_weight,
      [(((TRUE_VALUE < FALSE_VALUE) ? FALSE_VALUE : TRUE_VALUE) + 1):
       MAX_VALUE] :/ other_weight
    };
  }
endclass

class dist_mubi_live_max_shape;
  localparam bit [15:0] TRUE_VALUE = 16'ha5a5;
  localparam bit [15:0] FALSE_VALUE = 16'h5a5a;
  int live_max;
  int false_weight;
  int other_weight;
  rand bit [15:0] value;
  constraint value_c {
    value dist {
      TRUE_VALUE :/ (65535 * (live_max - 1)),
      FALSE_VALUE :/ (false_weight * (live_max - 1)),
      [0:(((TRUE_VALUE < FALSE_VALUE) ? TRUE_VALUE : FALSE_VALUE) - 1)]
        :/ other_weight,
      [(((TRUE_VALUE < FALSE_VALUE) ? TRUE_VALUE : FALSE_VALUE) + 1):
       (((TRUE_VALUE < FALSE_VALUE) ? FALSE_VALUE : TRUE_VALUE) - 1)]
        :/ other_weight,
      [(((TRUE_VALUE < FALSE_VALUE) ? FALSE_VALUE : TRUE_VALUE) + 1):
       live_max] :/ other_weight
    };
  }
endclass

class dist_ground_endpoint_expressions;
  localparam int WIDTH = 8;
  rand bit [7:0] pow_value;
  rand bit [7:0] shift_value;
  rand bit [3:0] xor_value;
  constraint pow_c { pow_value dist {[(2 ** WIDTH - 1):(2 ** WIDTH - 1)] :/ 1}; }
  constraint shift_c { shift_value dist {[((1 << WIDTH) - 7):((1 << WIDTH) - 7)] :/ 1}; }
  constraint xor_c { xor_value dist {[(4'ha ^ 4'hf):(4'ha ^ 4'hf)] :/ 1}; }
endclass

class dist_nested_endpoint_expressions;
  int unsigned valid_delay_max;
  bit [15:0] duration;
  bit [15:0] key;
  rand int unsigned divided_value;
  rand int unsigned sum_value;
  constraint divided_c {
    divided_value dist {[(valid_delay_max / 2 - 1):(valid_delay_max - 1)] :/ 1};
  }
  constraint divided_fixed_c { divided_value == 9; }
  constraint sum_c { sum_value dist {(duration + key + 5) :/ 1}; }
endclass

// Core Ibex computes a percentage endpoint as 9*max_interval/10. The
// multiply has full solver headroom, but SystemVerilog truncates it to the
// uint expression width before division. Use an overflowing product so the
// regression distinguishes those two orders: (9*32'hffff_ffff) wraps to
// 32'hffff_fff7 before the unsigned division.
class dist_multiply_then_divide_subject;
  rand int unsigned max_interval;
  constraint fixed_c { max_interval == 32'hffff_ffff; }
  constraint value_c {
    (9 * max_interval / 10) dist {32'd429496728 :/ 1};
  }
endclass

// Sysrst sequences combine uint16_t timers with positive unsized int
// literals. The outer 32-bit ring context must retain the exact mixed-width
// add/sub/multiply result.
class dist_mixed_width_ring_subject;
  rand bit [15:0] duration;
  rand bit [15:0] key;
  constraint fixed_c { duration == 16'hffff; key == 16'd1; }
  constraint subtract_c { ((duration + key) - 2) dist {32'd65534 :/ 1}; }
  constraint multiply_c { ((duration + key) * 2) dist {32'd131072 :/ 1}; }
endclass

// For a range, := gives each member the specified weight while :/ gives the
// complete item that weight. An unweighted integral item defaults to := 1.
class dist_range_per_value;
  rand bit [4:0] value;
  constraint value_c { value dist {[0:15] := 1, 16 := 1}; }
endclass

class dist_range_divided;
  rand bit [4:0] value;
  constraint value_c { value dist {[0:15] :/ 1, 16 :/ 1}; }
endclass

class dist_range_default_weight;
  rand bit [4:0] value;
  constraint value_c { value dist {[0:15], 16 := 1}; }
endclass

// A := range retains its aggregate full-range weight even when another
// constraint leaves only one member feasible.
class dist_range_pruned;
  rand bit [4:0] value;
  constraint domain_c { value >= 15; }
  constraint value_c { value dist {[0:15] := 1, 16 := 1}; }
endclass

// Overlapping items remain independent weighted choices, so their common
// value receives the sum of both item contributions.
class dist_range_overlap;
  rand bit [2:0] value;
  constraint value_c { value dist {[0:1] :/ 1, [1:2] :/ 1}; }
endclass

class dist_signed_crossing;
  rand bit signed [3:0] value;
  constraint value_c { value dist {[-2:2] := 1, 3 := 1}; }
endclass

class dist_signed_narrow_crossing;
  rand bit signed [3:0] value;
  constraint value_c { value dist {[-4'sd2:4'sd2] := 1, 3 := 1}; }
endclass

class dist_signed_crossing_pruned;
  rand bit signed [3:0] value;
  constraint domain_c { value >= 2; }
  constraint value_c { value dist {[-2:2] := 1, 3 := 1}; }
endclass

// `$` keeps the lower endpoint open. This range covers the signed subject
// domain minimum through 2 and has one aggregate :/ weight.
class dist_signed_open_lower;
  rand bit signed [3:0] value;
  constraint value_c { value dist {[$:2] :/ 1, 3 :/ 1}; }
endclass

// A zero-weight item does not exclude a value that is present in another
// nonzero item; the enclosing range remains uniform over all three values.
class dist_zero_overlap;
  rand bit [7:0] value;
  constraint value_c { value dist {100 :/ 0, [100:102] :/ 1}; }
endclass

class dist_weight_wrap_zero;
  rand bit value;
  constraint value_c {
    value dist {0 :/ (32'hffff_ffff + 1), 1 :/ 1};
  }
endclass

class dist_signed_subject_unsigned_bounds;
  rand bit signed [7:0] value;
  constraint value_c {
    value dist {[8'h00:8'h80] := 1, 8'h81 := 1};
  }
endclass

// Resolve a distribution when its subject's solve-before rank becomes due.
// Installing weighted-soft preferences before staging used to pin the
// heavier value deterministically instead of sampling the declared ratio.
class dist_solve_before_subject;
  rand bit subject;
  rand bit dependent;
  constraint value_c { subject dist {0 :/ 1, 1 :/ 3}; }
  constraint order_c { solve subject before dependent; }
endclass

// disable soft applies to the outer soft that owns a guarded distribution.
// It must not suppress an ordinary hard dist over that same subject.
class dist_outer_soft_disabled;
  rand bit guard;
  rand bit value;
  constraint preference_c { guard -> soft value dist {0 :/ 100, 1 :/ 1}; }
  constraint disable_c { disable soft value; }
endclass

class dist_hard_not_disabled;
  rand bit value;
  constraint value_c { value dist {0 :/ 0, 1 :/ 1}; }
  constraint disable_c { disable soft value; }
endclass

// Relational/equality context is unsigned if either operand is unsigned, so
// both operands zero-extend to the common width. The 4-bit pattern 4'he is
// therefore the unsigned value 14 in each of these opposite signedness cases.
class dist_signed_subject_wide_unsigned_value;
  rand bit signed [3:0] value;
  constraint value_c { value dist {32'd14 :/ 1}; }
endclass

class dist_unsigned_subject_narrow_signed_value;
  rand bit [7:0] value;
  constraint value_c { value dist {-4'sd2 :/ 1}; }
endclass

// Z3 hash-conses equal bitvector numerals. Signedness must remain metadata of
// each source occurrence: the signed zero in seed_c must not turn the unsigned
// low endpoint in value_c into a signed comparison and exclude value -2.
class dist_signed_constant_occurrence;
  rand bit signed [3:0] value;
  constraint seed_c { 4'sd0 == 4'sd0; }
  constraint fixed_c { value == -2; }
  constraint value_c {
    value dist {[4'd0:4'd14] :/ 1, 4'd15 :/ 1};
  }
endclass

// Exact member probing is deliberately capped; a larger range must preserve
// the hard domain and continue through the documented weighted-soft fallback.
class dist_range_over_exact_cap;
  rand bit [8:0] value;
  constraint value_c { value dist {[0:300] := 1, 301 := 1}; }
endclass

class dist_weight_over_uint_max;
  rand bit value;
  constraint value_c { value dist {0 :/ 64'h1_0000_0000, 1 :/ 1}; }
endclass

// The sum of these two individually supported weights is greater than 2^32.
// Exact item selection therefore needs an unbiased 64-bit ticket rather than
// scaling one 32-bit RNG word through floating point.
class dist_u64_aggregate_ticket;
  rand bit value;
  constraint value_c {
    value dist {0 :/ 32'hffff_ffff, 1 :/ 32'hffff_ffff};
  }
endclass

// A wide weight sort is representable when its value fits uint64. A ground
// result above uint64 remains a live branch on the loud saturated fallback;
// it must not be mistaken for a nonground expression and assigned zero weight.
class dist_weight_wide_zero_high;
  rand bit value;
  constraint value_c { value dist {0 :/ 128'sd1, 1 :/ 0}; }
endclass

class dist_weight_over_uint64;
  rand bit value;
  constraint value_c {
    value dist {0 :/ (128'd1099511627776 * 128'd1099511627776), 1 :/ 1};
  }
endclass

// A fallback-managed expression must retain control of all subject leaves.
// Uniformly pinning a and b before Optimize would make this strong scalar
// branch ineffective even though its fallback weight dominates the range.
class dist_expression_over_exact_cap;
  rand bit [8:0] a;
  rand bit [8:0] b;
  constraint value_c { (a + b) dist {[0:300] :/ 1, 301 :/ 100}; }
endclass

module main;
  dist_boolean_subject item;
  dist_countones_root_subject countones_item;
  dist_countones_bnot_subject countones_bnot_item;
  dist_terminal_comparison_subject comparison_item;
  dist_arithmetic_subject arithmetic_item;
  dist_signed_arithmetic_subject signed_arithmetic_item;
  dist_mixed_arithmetic_subject mixed_arithmetic_item;
  dist_multiply_subject multiply_item;
  dist_signed_subtract_subject signed_subtract_item;
  dist_unsigned_divide_subject unsigned_divide_item;
  dist_signed_modulus_subject signed_modulus_item;
  dist_modulus_subject modulus_item;
  dist_bitwise_not_subject bitwise_not_item;
  dist_fill_terminal_subject fill_terminal_item;
  dist_fill_bnot_subject fill_bnot_item;
  dist_concat_fill_subject concat_fill_item;
  dist_concat_terminal_subject concat_terminal_item;
  dist_repeat_concat_endpoint repeat_concat_item;
  dist_bit_select_subject bit_select_item;
  dist_ternary_weight ternary_weight_item;
  dist_nested_sub_weight nested_sub_weight_item;
  dist_nested_add_sub_weight nested_add_sub_weight_item;
  dist_nested_divide_weight nested_divide_weight_item;
  dist_mubi_macro_shape mubi_item;
  dist_mubi_live_max_shape mubi_live_max_item;
  dist_ground_endpoint_expressions ground_endpoint_item;
  dist_nested_endpoint_expressions nested_endpoint_item;
  dist_multiply_then_divide_subject multiply_divide_item;
  dist_mixed_width_ring_subject mixed_width_ring_item;
  dist_range_per_value per_value_item;
  dist_range_divided divided_item;
  dist_range_default_weight default_item;
  dist_range_pruned pruned_item;
  dist_range_overlap overlap_item;
  dist_signed_crossing signed_item;
  dist_signed_narrow_crossing signed_narrow_item;
  dist_signed_crossing_pruned signed_pruned_item;
  dist_signed_open_lower signed_open_item;
  dist_zero_overlap zero_overlap_item;
  dist_weight_wrap_zero weight_wrap_item;
  dist_signed_subject_unsigned_bounds unsigned_bounds_item;
  dist_solve_before_subject ordered_item;
  dist_outer_soft_disabled soft_disabled_item;
  dist_hard_not_disabled hard_not_disabled_item;
  dist_signed_subject_wide_unsigned_value wide_unsigned_item;
  dist_unsigned_subject_narrow_signed_value narrow_signed_item;
  dist_signed_constant_occurrence signed_constant_item;
  dist_range_over_exact_cap over_cap_item;
  dist_weight_over_uint_max over_uint_item;
  dist_u64_aggregate_ticket u64_ticket_item;
  dist_weight_wide_zero_high wide_weight_item;
  dist_weight_over_uint64 over_uint64_item;
  dist_expression_over_exact_cap expression_fallback_item;
  int one_hot;
  int other;
  int fill_terminal_all;
  int fill_terminal_other;
  int fill_terminal_wide;
  int comparison_equal;
  int comparison_unequal;
  int nested_sub_zero;
  int nested_sub_one;
  int nested_add_sub_zero;
  int nested_add_sub_one;
  bit [15:0] u64_ticket_sequence;
  integer u64_ticket_index;
  int sum_two;
  int sum_seventeen;
  int signed_sum_range;
  int signed_sum_scalar;
  int per_value_range;
  int per_value_scalar;
  int divided_range;
  int divided_scalar;
  int default_range;
  int default_scalar;
  int pruned_range;
  int pruned_scalar;
  int overlap_zero;
  int overlap_one;
  int overlap_two;
  int signed_range;
  int signed_scalar;
  int signed_narrow_range;
  int signed_narrow_scalar;
  int signed_pruned_range;
  int signed_pruned_scalar;
  int signed_open_range;
  int signed_open_scalar;
  int zero_overlap_100;
  int zero_overlap_101;
  int zero_overlap_102;
  int unsigned_bounds_range;
  int unsigned_bounds_scalar;
  int ordered_zero;
  int ordered_one;
  int soft_disabled_zero;
  int soft_disabled_one;

  initial begin
    item = new;
    item.srandom(32'h484d4143);
    repeat (100) begin
      if (!item.randomize())
        $fatal(1, "boolean-subject dist unexpectedly unsatisfiable");
      if ($countones(item.digest_size) == 1)
        one_hot++;
      else
        other++;
    end
    // Also reject the old weighted-soft fallback, which always selected the
    // feasible heavier branch instead of sampling the 4:1 distribution.
    if (one_hot < 65 || one_hot > 95 || other != 100 - one_hot)
      $fatal(1, "boolean dist weights not observed: one_hot=%0d other=%0d",
             one_hot, other);

    countones_item = new;
    repeat (8) begin
      if (!countones_item.randomize() || $countones(countones_item.value) != 1)
        $fatal(1, "root countones dist subject failed");
    end

    countones_bnot_item = new;
    repeat (8) begin
      if (!countones_bnot_item.randomize() ||
          $countones(~countones_bnot_item.value) != 1)
        $fatal(1, "root countones-complement dist subject failed");
    end

    comparison_item = new;
    comparison_item.max_key_version = 8'h5a;
    comparison_item.srandom(32'h434f4d50);
    repeat (96) begin
      if (!comparison_item.randomize())
        $fatal(1, "terminal comparison dist subject failed");
      if (comparison_item.key_version == comparison_item.max_key_version)
        comparison_equal++;
      else
        comparison_unequal++;
    end
    if (comparison_equal < 15 || comparison_equal > 40 ||
        comparison_unequal != 96 - comparison_equal)
      $fatal(1, "terminal comparison weights lost: equal=%0d unequal=%0d",
             comparison_equal, comparison_unequal);

    arithmetic_item = new;
    arithmetic_item.srandom(32'h41524954);
    repeat (100) begin
      if (!arithmetic_item.randomize())
        $fatal(1, "arithmetic expression dist failed");
      if (arithmetic_item.a + arithmetic_item.b == 2)
        sum_two++;
      else if (arithmetic_item.a + arithmetic_item.b == 17)
        sum_seventeen++;
      else
        $fatal(1, "arithmetic expression escaped dist domain");
    end
    if (sum_two < 20 || sum_seventeen < 20)
      $fatal(1, "arithmetic expression dist not sampled: two=%0d seventeen=%0d",
             sum_two, sum_seventeen);

    signed_arithmetic_item = new;
    signed_arithmetic_item.srandom(32'h53415249);
    repeat (96) begin
      if (!signed_arithmetic_item.randomize())
        $fatal(1, "signed arithmetic expression dist failed");
      if (signed_arithmetic_item.a + signed_arithmetic_item.b >= -2 &&
          signed_arithmetic_item.a + signed_arithmetic_item.b <= 2)
        signed_sum_range++;
      else if (signed_arithmetic_item.a + signed_arithmetic_item.b == 3)
        signed_sum_scalar++;
      else
        $fatal(1, "signed arithmetic expression escaped dist domain");
    end
    if (signed_sum_range < 70 ||
        signed_sum_scalar != 96 - signed_sum_range)
      $fatal(1, "signed arithmetic result lost signed range order: range=%0d scalar=%0d",
             signed_sum_range, signed_sum_scalar);

    mixed_arithmetic_item = new;
    repeat (8) begin
      if (!mixed_arithmetic_item.randomize() ||
          mixed_arithmetic_item.signed_value != -2 ||
          mixed_arithmetic_item.unsigned_zero != 0)
        $fatal(1, "mixed arithmetic operands did not share unsigned context");
    end

    multiply_item = new;
    repeat (8) begin
      if (!multiply_item.randomize() || multiply_item.a * multiply_item.b != 100)
        $fatal(1, "flat multiply dist subject failed");
    end

    signed_subtract_item = new;
    repeat (8) begin
      if (!signed_subtract_item.randomize() ||
          signed_subtract_item.a - signed_subtract_item.b < -2 ||
          signed_subtract_item.a - signed_subtract_item.b > 3)
        $fatal(1, "flat signed subtract dist subject failed");
    end

    unsigned_divide_item = new;
    repeat (8) begin
      if (!unsigned_divide_item.randomize() ||
          unsigned_divide_item.value / 2 != 3)
        $fatal(1, "flat unsigned divide dist subject failed");
    end

    signed_modulus_item = new;
    repeat (8) begin
      if (!signed_modulus_item.randomize() ||
          signed_modulus_item.value % 3 != -2)
        $fatal(1, "flat signed modulus dist subject failed");
    end

    modulus_item = new;
    repeat (8) begin
      if (!modulus_item.randomize() || modulus_item.value % 16 != 0)
        $fatal(1, "flat modulus dist subject failed");
    end

    bitwise_not_item = new;
    repeat (8) begin
      if (!bitwise_not_item.randomize() || bitwise_not_item.value != 4'ha)
        $fatal(1, "unary bitwise-not dist subject failed");
    end

    fill_terminal_item = new;
    fill_terminal_item.srandom(32'h46494c4c);
    repeat (96) begin
      if (!fill_terminal_item.randomize())
        $fatal(1, "terminal fill-literal dist failed");
      if (fill_terminal_item.value == 4'hf)
        fill_terminal_all++;
      else begin
        fill_terminal_other++;
        if (fill_terminal_item.value > 1) fill_terminal_wide++;
      end
    end
    if (fill_terminal_all < 70 || fill_terminal_all >= 96 ||
        fill_terminal_other != 96 - fill_terminal_all ||
        fill_terminal_wide == 0)
      $fatal(1, "terminal fill range/domain lost: all=%0d other=%0d wide=%0d",
             fill_terminal_all, fill_terminal_other, fill_terminal_wide);

    fill_bnot_item = new;
    repeat (4)
      if (!fill_bnot_item.randomize() ||
          ~fill_bnot_item.value != 32'hffff_fffe)
        $fatal(1, "complemented exact-source fill range lost its wide domain");

    concat_fill_item = new;
    repeat (4) begin
      if (!concat_fill_item.randomize() || concat_fill_item.dai_addr != 8'hfc)
        $fatal(1, "fixed-part concat fill range failed");
    end


    concat_terminal_item = new;
    repeat (4) begin
      if (!concat_terminal_item.randomize() ||
          {concat_terminal_item.boot_req_mode,
           concat_terminal_item.auto_req_mode} != 4'b1001)
        $fatal(1, "terminal concat dist subject failed");
    end


    repeat_concat_item = new;
    repeat (4) begin
      if (!repeat_concat_item.randomize() ||
          repeat_concat_item.address != 16'hffff)
        $fatal(1, "ground replication-concat dist endpoint failed");
    end

    bit_select_item = new;
    repeat (4) begin
      if (!bit_select_item.randomize() || bit_select_item.index != 2 ||
          bit_select_item.periph_to_mio_oe[bit_select_item.index] != 0)
        $fatal(1, "packed bit-select dist subject failed");
    end

    ternary_weight_item = new;
    ternary_weight_item.invalidate = 1;
    ternary_weight_item.enable = 0;
    repeat (4)
      if (!ternary_weight_item.randomize() || ternary_weight_item.value != 0)
        $fatal(1, "outer ternary dist weight selected the wrong branch");
    ternary_weight_item.invalidate = 0;
    ternary_weight_item.enable = 1;
    repeat (4)
      if (!ternary_weight_item.randomize() || ternary_weight_item.value != 1)
        $fatal(1, "nested ternary dist weight selected the wrong branch");

    nested_sub_weight_item = new;
    nested_sub_weight_item.boot_req_mode_pct = 30;
    nested_sub_weight_item.auto_req_mode_pct = 30;
    nested_sub_weight_item.srandom(32'h45444e57);
    repeat (192) begin
      if (!nested_sub_weight_item.randomize())
        $fatal(1, "nested subtraction dist weight failed");
      if (nested_sub_weight_item.value)
        nested_sub_one++;
      else
        nested_sub_zero++;
    end
    if (nested_sub_one == 0 || nested_sub_one > 16 ||
        nested_sub_zero != 192 - nested_sub_one)
      $fatal(1, "nested subtraction weight was not 40:1: zero=%0d one=%0d",
             nested_sub_zero, nested_sub_one);
    nested_sub_weight_item.boot_req_mode_pct = 80;
    nested_sub_weight_item.auto_req_mode_pct = 80;
    repeat (4)
      if (!nested_sub_weight_item.randomize() || nested_sub_weight_item.value)
        $fatal(1, "nested subtraction uint underflow did not wrap exactly");

    nested_add_sub_weight_item = new;
    nested_add_sub_weight_item.rx_only_weight = 30;
    nested_add_sub_weight_item.dummy_weight = 20;
    nested_add_sub_weight_item.srandom(32'h53504957);
    repeat (192) begin
      if (!nested_add_sub_weight_item.randomize())
        $fatal(1, "nested add-under-sub dist weight failed");
      if (nested_add_sub_weight_item.value)
        nested_add_sub_one++;
      else
        nested_add_sub_zero++;
    end
    if (nested_add_sub_one == 0 || nested_add_sub_one > 16 ||
        nested_add_sub_zero != 192 - nested_add_sub_one)
      $fatal(1, "nested add-under-sub weight was not 50:1: zero=%0d one=%0d",
             nested_add_sub_zero, nested_add_sub_one);

    nested_divide_weight_item = new;
    nested_divide_weight_item.percentage = 98;
    repeat (4)
      if (!nested_divide_weight_item.randomize() ||
          nested_divide_weight_item.value != 0)
        $fatal(1, "nested subtraction/division MUBI weight failed");

    mubi_item = new;
    mubi_item.true_weight = 1;
    mubi_item.false_weight = 0;
    mubi_item.other_weight = 0;
    repeat (4)
      if (!mubi_item.randomize() || mubi_item.value != 4'ha)
        $fatal(1, "ground-folded MUBI macro distribution failed");

    mubi_live_max_item = new;
    mubi_live_max_item.live_max = 65535;
    mubi_live_max_item.false_weight = 0;
    mubi_live_max_item.other_weight = 0;
    repeat (2)
      if (!mubi_live_max_item.randomize() ||
          mubi_live_max_item.value != 16'ha5a5)
        $fatal(1, "live-MAX MUBI macro distribution failed");

    ground_endpoint_item = new;
    repeat (4) begin
      if (!ground_endpoint_item.randomize() ||
          ground_endpoint_item.pow_value != 8'hff ||
          ground_endpoint_item.shift_value != 8'd249 ||
          ground_endpoint_item.xor_value != 4'h5)
        $fatal(1, "ground pow/shift/xor dist endpoint folding failed");
    end

    nested_endpoint_item = new;
    nested_endpoint_item.valid_delay_max = 20;
    nested_endpoint_item.duration = 10;
    nested_endpoint_item.key = 5;
    repeat (4) begin
      if (!nested_endpoint_item.randomize() ||
          nested_endpoint_item.divided_value != 9 ||
          nested_endpoint_item.sum_value != 20)
        $fatal(1, "nested state arithmetic dist endpoint failed");
    end

    multiply_divide_item = new;
    repeat (4)
      if (!multiply_divide_item.randomize() ||
          multiply_divide_item.max_interval != 32'hffff_ffff)
        $fatal(1, "multiply-before-divide semantic truncation failed");

    mixed_width_ring_item = new;
    repeat (4)
      if (!mixed_width_ring_item.randomize() ||
          mixed_width_ring_item.duration != 16'hffff ||
          mixed_width_ring_item.key != 16'd1)
        $fatal(1, "mixed-width uint16/int ring expression failed");

    per_value_item = new;
    per_value_item.srandom(32'h50455256);
    repeat (96) begin
      if (!per_value_item.randomize())
        $fatal(1, ":= range dist failed");
      if (per_value_item.value <= 15)
        per_value_range++;
      else if (per_value_item.value == 16)
        per_value_scalar++;
      else
        $fatal(1, ":= range escaped dist domain");
    end
    if (per_value_range < 80 || per_value_scalar != 96 - per_value_range)
      $fatal(1, ":= range aggregate weight lost: range=%0d scalar=%0d",
             per_value_range, per_value_scalar);

    divided_item = new;
    divided_item.srandom(32'h44495644);
    repeat (96) begin
      if (!divided_item.randomize())
        $fatal(1, ":/ range dist failed");
      if (divided_item.value <= 15)
        divided_range++;
      else if (divided_item.value == 16)
        divided_scalar++;
      else
        $fatal(1, ":/ range escaped dist domain");
    end
    if (divided_range < 30 || divided_range > 66 ||
        divided_scalar != 96 - divided_range)
      $fatal(1, ":/ range aggregate weight changed: range=%0d scalar=%0d",
             divided_range, divided_scalar);

    default_item = new;
    default_item.srandom(32'h44454654);
    repeat (96) begin
      if (!default_item.randomize())
        $fatal(1, "default-weight range dist failed");
      if (default_item.value <= 15)
        default_range++;
      else if (default_item.value == 16)
        default_scalar++;
      else
        $fatal(1, "default-weight range escaped dist domain");
    end
    if (default_range < 80 || default_scalar != 96 - default_range)
      $fatal(1, "default := 1 range weight lost: range=%0d scalar=%0d",
             default_range, default_scalar);

    pruned_item = new;
    pruned_item.srandom(32'h5052554e);
    repeat (96) begin
      if (!pruned_item.randomize())
        $fatal(1, "pruned := range dist failed");
      if (pruned_item.value == 15)
        pruned_range++;
      else if (pruned_item.value == 16)
        pruned_scalar++;
      else
        $fatal(1, "pruned := range escaped feasible domain");
    end
    if (pruned_range < 80 || pruned_scalar != 96 - pruned_range)
      $fatal(1, "pruned := range lost full aggregate: range=%0d scalar=%0d",
             pruned_range, pruned_scalar);

    overlap_item = new;
    overlap_item.srandom(32'h4f564552);
    repeat (160) begin
      if (!overlap_item.randomize())
        $fatal(1, "overlapping range dist failed");
      case (overlap_item.value)
        0: overlap_zero++;
        1: overlap_one++;
        2: overlap_two++;
        default: $fatal(1, "overlapping ranges escaped dist domain");
      endcase
    end
    if (overlap_one < 55 || overlap_one > 105 ||
        overlap_zero < 20 || overlap_two < 20 ||
        overlap_zero + overlap_one + overlap_two != 160)
      $fatal(1, "overlapping range weights not additive: zero=%0d one=%0d two=%0d",
             overlap_zero, overlap_one, overlap_two);

    signed_item = new;
    signed_item.srandom(32'h5349474e);
    repeat (96) begin
      if (!signed_item.randomize())
        $fatal(1, "signed crossing range dist failed");
      if (signed_item.value >= -2 && signed_item.value <= 2)
        signed_range++;
      else if (signed_item.value == 3)
        signed_scalar++;
      else
        $fatal(1, "signed crossing range escaped dist domain");
    end
    if (signed_range < 70 || signed_scalar != 96 - signed_range)
      $fatal(1, "signed crossing range aggregate lost: range=%0d scalar=%0d",
             signed_range, signed_scalar);

    signed_narrow_item = new;
    signed_narrow_item.srandom(32'h4e415252);
    repeat (96) begin
      if (!signed_narrow_item.randomize())
        $fatal(1, "narrow signed crossing range dist failed");
      if (signed_narrow_item.value >= -2 && signed_narrow_item.value <= 2)
        signed_narrow_range++;
      else if (signed_narrow_item.value == 3)
        signed_narrow_scalar++;
      else
        $fatal(1, "narrow signed range escaped dist domain");
    end
    if (signed_narrow_range < 70 ||
        signed_narrow_scalar != 96 - signed_narrow_range)
      $fatal(1, "narrow signed range aggregate lost: range=%0d scalar=%0d",
             signed_narrow_range, signed_narrow_scalar);

    signed_pruned_item = new;
    signed_pruned_item.srandom(32'h5350524e);
    repeat (96) begin
      if (!signed_pruned_item.randomize())
        $fatal(1, "pruned signed crossing range dist failed");
      if (signed_pruned_item.value == 2)
        signed_pruned_range++;
      else if (signed_pruned_item.value == 3)
        signed_pruned_scalar++;
      else
        $fatal(1, "pruned signed range escaped feasible domain");
    end
    if (signed_pruned_range < 70 ||
        signed_pruned_scalar != 96 - signed_pruned_range)
      $fatal(1, "pruned signed range lost full aggregate: range=%0d scalar=%0d",
             signed_pruned_range, signed_pruned_scalar);

    signed_open_item = new;
    signed_open_item.srandom(32'h4f50454e);
    repeat (96) begin
      if (!signed_open_item.randomize())
        $fatal(1, "signed open range dist failed");
      if (signed_open_item.value <= 2)
        signed_open_range++;
      else if (signed_open_item.value == 3)
        signed_open_scalar++;
      else
        $fatal(1, "signed open range escaped dist domain");
    end
    if (signed_open_range < 30 || signed_open_range > 66 ||
        signed_open_scalar != 96 - signed_open_range)
      $fatal(1, "signed open :/ aggregate changed: range=%0d scalar=%0d",
             signed_open_range, signed_open_scalar);

    zero_overlap_item = new;
    zero_overlap_item.srandom(32'h5a45524f);
    repeat (180) begin
      if (!zero_overlap_item.randomize())
        $fatal(1, "zero-overlap range dist failed");
      case (zero_overlap_item.value)
        100: zero_overlap_100++;
        101: zero_overlap_101++;
        102: zero_overlap_102++;
        default: $fatal(1, "zero-overlap range escaped dist domain");
      endcase
    end
    if (zero_overlap_100 < 35 || zero_overlap_100 > 85 ||
        zero_overlap_101 < 35 || zero_overlap_101 > 85 ||
        zero_overlap_102 < 35 || zero_overlap_102 > 85)
      $fatal(1, "zero-overlap range not uniform: 100=%0d 101=%0d 102=%0d",
             zero_overlap_100, zero_overlap_101, zero_overlap_102);

    weight_wrap_item = new;
    weight_wrap_item.srandom(32'h57524150);
    repeat (20) begin
      if (!weight_wrap_item.randomize() || weight_wrap_item.value != 1)
        $fatal(1, "wrapped zero dist weight admitted value 0");
    end

    unsigned_bounds_item = new;
    unsigned_bounds_item.srandom(32'h554e5347);
    repeat (96) begin
      if (!unsigned_bounds_item.randomize())
        $fatal(1, "signed subject with unsigned bounds failed");
      if ($unsigned(unsigned_bounds_item.value) <= 8'h80)
        unsigned_bounds_range++;
      else if ($unsigned(unsigned_bounds_item.value) == 8'h81)
        unsigned_bounds_scalar++;
      else
        $fatal(1, "unsigned-bound range escaped dist domain");
    end
    if (unsigned_bounds_range < 90 ||
        unsigned_bounds_scalar != 96 - unsigned_bounds_range)
      $fatal(1, "unsigned-bound range used signed order: range=%0d scalar=%0d",
             unsigned_bounds_range, unsigned_bounds_scalar);

    ordered_item = new;
    ordered_item.srandom(32'h4f524452);
    repeat (128) begin
      if (!ordered_item.randomize())
        $fatal(1, "solve-before dist failed");
      if (ordered_item.subject)
        ordered_one++;
      else
        ordered_zero++;
    end
    if (ordered_zero < 15 || ordered_zero > 50 ||
        ordered_one != 128 - ordered_zero)
      $fatal(1, "solve-before pinned weighted-soft value: zero=%0d one=%0d",
             ordered_zero, ordered_one);

    soft_disabled_item = new;
    soft_disabled_item.srandom(32'h53444953);
    repeat (96) begin
      if (!soft_disabled_item.randomize())
        $fatal(1, "disabled outer soft dist failed");
      if (soft_disabled_item.value)
        soft_disabled_one++;
      else
        soft_disabled_zero++;
    end
    if (soft_disabled_zero < 25 || soft_disabled_one < 25)
      $fatal(1, "disable soft left nested dist active: zero=%0d one=%0d",
             soft_disabled_zero, soft_disabled_one);

    hard_not_disabled_item = new;
    repeat (16) begin
      if (!hard_not_disabled_item.randomize() ||
          hard_not_disabled_item.value != 1)
        $fatal(1, "disable soft suppressed an ordinary hard dist");
    end

    wide_unsigned_item = new;
    repeat (8) begin
      if (!wide_unsigned_item.randomize() || wide_unsigned_item.value != -2)
        $fatal(1, "signed subject was sign-extended in unsigned context");
    end

    narrow_signed_item = new;
    repeat (8) begin
      if (!narrow_signed_item.randomize() || narrow_signed_item.value != 14)
        $fatal(1, "signed value was sign-extended in unsigned context");
    end

    signed_constant_item = new;
    repeat (4) begin
      if (!signed_constant_item.randomize() ||
          signed_constant_item.value != -2)
        $fatal(1, "signed constant metadata contaminated an unsigned range");
    end

    over_cap_item = new;
    repeat (8) begin
      if (!over_cap_item.randomize() || over_cap_item.value > 301)
        $fatal(1, "over-cap dist fallback escaped its hard domain");
    end

    over_uint_item = new;
    repeat (8) begin
      if (!over_uint_item.randomize() || over_uint_item.value != 0)
        $fatal(1, "over-UINT_MAX dist fallback lost its dominant branch");
    end

    u64_ticket_item = new;
    u64_ticket_item.srandom(32'h55363454);
    for (u64_ticket_index = 0; u64_ticket_index < 16;
         u64_ticket_index++) begin
      if (!u64_ticket_item.randomize())
        $fatal(1, "64-bit aggregate ticket distribution failed");
      u64_ticket_sequence[u64_ticket_index] = u64_ticket_item.value;
    end
    // The former one-word/double sampler produces 16'h60d9 from this seed;
    // the two-word integer-ticket path produces the pinned sequence. This
    // deterministic control pins which path is used; the rejection algorithm's
    // lack of modulo bias follows from its complete-residue acceptance range.
    if (u64_ticket_sequence != 16'h97a5)
      $fatal(1, "64-bit aggregate ticket path changed: got %h",
             u64_ticket_sequence);

    wide_weight_item = new;
    repeat (8) begin
      if (!wide_weight_item.randomize() || wide_weight_item.value != 0)
        $fatal(1, "representable 128-bit weight was not evaluated as one");
    end

    over_uint64_item = new;
    repeat (8) begin
      if (!over_uint64_item.randomize() || over_uint64_item.value != 0)
        $fatal(1, "over-uint64 weight was dropped instead of using fallback");
    end

    expression_fallback_item = new;
    repeat (16) begin
      if (!expression_fallback_item.randomize() ||
          expression_fallback_item.a + expression_fallback_item.b != 301)
        $fatal(1, "expression dist fallback was overridden by leaf sampling");
    end
    $display("PASSED");
  end
endmodule
