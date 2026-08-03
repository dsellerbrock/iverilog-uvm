`begin_keywords "1800-2012"

module main;
  logic [1:0] clipped_data;
  logic [3:0] wide_data;
  logic [2:0] upper_data;
  logic [3:0] result;
  logic [1:0] wide_result;

  // The first assignment overlaps only result[0]. Exact ownership must clip
  // the constant select instead of treating it like a run-time select or a
  // whole-vector write.
  always_comb result[-1 +: 2] = clipped_data;
  always_comb result[3:1] = upper_data;
  always_comb wide_result[-1 +: 4] = wide_data;

  task automatic check(input logic [1:0] next_clipped,
                       input logic [2:0] next_upper,
                       input logic [3:0] next_wide);
    clipped_data = next_clipped;
    upper_data = next_upper;
    wide_data = next_wide;
    #1;
    if (result !== {upper_data, clipped_data[1]} ||
        wide_result !== wide_data[2:1]) begin
      $display("FAILED -- clipped=%b upper=%b result=%b wide=%b/%b",
               clipped_data, upper_data, result, wide_result, wide_data);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(2'b01, 3'b101, 4'b0010);
    check(2'b10, 3'b010, 4'b0100);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
