`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    logic [3:0] high;
    logic [3:0] low;
  } pair_t;

  logic [7:0] and_source;
  logic [7:0] add_source;
  pair_t and_result;
  pair_t add_result;

  always_comb begin
    and_result.high = and_source[7:4];
    and_result.low = and_source[3:0];
    {and_result.high, and_result.low} &= 8'h0f;

    add_result.high = add_source[7:4];
    add_result.low = add_source[3:0];
    // The carry must cross the l-value leaf boundary. Applying += to each
    // four-bit leaf independently produces 8'h00 instead of 8'h10.
    {add_result.high, add_result.low} += 8'h01;
  end

  (* ivl_synthesis_off *)
  initial begin
    and_source = 8'ha5;
    add_source = 8'h0f;
    #1;
    if ({and_result, add_result} !== {8'h05, 8'h10})
      $fatal(1, "first concat compound result: %h %h",
             and_result, add_result);

    and_source = 8'hf3;
    add_source = 8'hff;
    #1;
    if ({and_result, add_result} !== {8'h03, 8'h00})
      $fatal(1, "updated concat compound result: %h %h",
             and_result, add_result);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
