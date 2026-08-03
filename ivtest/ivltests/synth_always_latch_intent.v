`begin_keywords "1800-2012"

module main;
  logic enable;
  logic data;
  logic stored;

  // The process explicitly requests a latch. Synthesis should implement it
  // without reporting the expected incomplete assignment as inferred-latch
  // debt; ordinary always_comb/always @* inference remains diagnostic.
  always_latch begin
    if (enable)
      stored = data;
  end

  task automatic check(input logic en, input logic value,
                       input logic expected);
    enable = en;
    data = value;
    #1;
    if (stored !== expected) begin
      $display("FAILED -- enable=%b data=%b stored=%b expected=%b",
               enable, data, stored, expected);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(1'b1, 1'b0, 1'b0);
    check(1'b0, 1'b1, 1'b0);
    check(1'b1, 1'b1, 1'b1);
    check(1'b0, 1'b0, 1'b1);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
