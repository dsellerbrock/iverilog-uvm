// IEEE 1800-2017/2023 11.4.13, 11.8, 19.3, and 19.5.1:
// constructor-dependent bin endpoints retain their SystemVerilog width and
// signedness, input arguments are captured by value, and reversed explicit
// ranges are empty.
module top;
  covergroup cg_shift(bit [7:0] base, int count)
      with function sample(bit [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins values[] = {[0:(base << count)]};
    }
  endgroup

  covergroup cg_arith(bit [7:0] base)
      with function sample(bit [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins values[] = {[0:(base * 2) + 1]};
    }
  endgroup

  covergroup cg_capture(int limit) with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins captured = {[0:limit-1]};
    }
  endgroup

  covergroup cg_empty(int low) with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins reversed[] = {[low:2]};
    }
  endgroup

  covergroup cg_fixed(int limit) with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins fixed[4] = {[1:limit], 1, 4, 7};
    }
  endgroup

  covergroup cg_fill_zero(int limit) with function sample(bit [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins zero = {[1:limit], '0};
      bins zero_tree = {[0:(limit & '0)]};
    }
  endgroup

  covergroup cg_unary(int limit) with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins symmetric = {[-limit:limit]};
    }
  endgroup

  cg_shift wrapped_shift;
  cg_shift large_shift;
  cg_shift negative_shift;
  cg_arith mixed_width;
  cg_capture captured;
  cg_empty reversed;
  cg_fixed fixed_partition;
  cg_fill_zero fill_zero;
  cg_unary unary_range;
  int actual_limit;

  initial begin
    // The result width of a shift is the left operand width. 8'h80 << 1
    // wraps to 8'h00 rather than becoming the host-integer value 256.
    wrapped_shift = new(8'h80, 1);
    wrapped_shift.sample(0);
    if (wrapped_shift.get_inst_coverage() != 100.0)
      $fatal(1, "fixed-width left shift did not wrap at eight bits");

    // A shift count greater than or equal to the left width yields zero.
    large_shift = new(8'h01, 8);
    large_shift.sample(0);
    if (large_shift.get_inst_coverage() != 100.0)
      $fatal(1, "large shift count did not yield the typed zero result");

    // A negative signed count is interpreted as its self-determined bit
    // pattern and is therefore also greater than the left operand width.
    negative_shift = new(8'h01, -1);
    negative_shift.sample(0);
    if (negative_shift.get_inst_coverage() != 100.0)
      $fatal(1, "negative shift count did not yield the typed zero result");

    // Unsized decimal literals make this tree 32-bit unsigned because base
    // is unsigned. The eight selected values become eight open-array bins.
    mixed_width = new(3);
    mixed_width.sample(7);
    if (mixed_width.get_inst_coverage() != 12.5)
      $fatal(1, "mixed-width arithmetic did not create eight bins");

    // A non-ref constructor argument is captured when new executes.
    actual_limit = 2;
    captured = new(actual_limit);
    actual_limit = 4;
    captured.sample(3);
    if (captured.get_inst_coverage() != 0.0)
      $fatal(1, "input constructor argument tracked the changed actual");
    captured.sample(1);
    if (captured.get_inst_coverage() != 100.0)
      $fatal(1, "captured constructor argument did not define the bin");

    // Unlike tolerance ranges, an explicit [low:high] with low > high is
    // empty and must not be silently reordered.
    reversed = new(5);
    reversed.sample(5);
    if (reversed.get_inst_coverage() != 0.0)
      $fatal(1, "reversed explicit range was incorrectly swapped");

    // IEEE 1800-2017/2023 19.5.1 retains duplicates in the ordered list.
    // The 13 values split into {1,2,3}, {4,5,6}, {7,8,9}, and
    // {10,1,4,7}. A value duplicated into the last bin hits both bins.
    fixed_partition = new(10);
    fixed_partition.sample(1);
    if (fixed_partition.get_inst_coverage() != 50.0)
	  $fatal(1, "duplicate value did not hit both fixed bins");
    fixed_partition.sample(4);
    if (fixed_partition.get_inst_coverage() != 75.0)
	  $fatal(1, "second duplicate did not hit its fixed bin");
    fixed_partition.sample(7);
    if (fixed_partition.get_inst_coverage() != 100.0)
	  $fatal(1, "fixed-bin duplicate partition did not reach all bins");

    // The generic typed IR can safely context-fill an unbased '0 both as a
    // static sibling and inside a constructor-dependent bitwise tree.
    fill_zero = new(1);
    fill_zero.sample(0);
    if (fill_zero.get_inst_coverage() != 100.0)
	  $fatal(1, "unbased '0 sibling did not retain its fill value");

    // Unary minus retains the constructor formal's signed 32-bit type.
    unary_range = new(2);
    unary_range.sample(-2);
    if (unary_range.get_inst_coverage() != 100.0)
	  $fatal(1, "typed unary-minus endpoint was not evaluated");

    $display("PASSED");
  end
endmodule
