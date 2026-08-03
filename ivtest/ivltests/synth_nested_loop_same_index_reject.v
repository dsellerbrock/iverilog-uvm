`begin_keywords "1800-2012"

module main;
  logic [2:0] source;
  logic [2:0] result;
  integer index;

  // Both loops intentionally control the same variable. The inner loop's
  // terminal value becomes the outer loop's value too; until synthesis models
  // that shared state, it must reject the construct instead of silently using
  // two independent unrolled values.
  always_comb begin
    result = source;
    for (index = 0; index < 2; index++) begin
      for (index = 0; index < 1; index++) begin
        result = result + 1'b1;
      end
      result = result + 1'b1;
    end
  end

  task automatic check(input logic [2:0] stimulus,
                       input logic [2:0] expected);
    source = stimulus;
    #1;
    if (result !== expected) begin
      $display("FAILED -- source=%0d result=%0d expected=%0d",
               source, result, expected);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(3'd0, 3'd2);
    check(3'd3, 3'd5);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
