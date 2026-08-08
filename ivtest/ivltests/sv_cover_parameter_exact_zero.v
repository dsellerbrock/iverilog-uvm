// IEEE 1800-2017 16.9.2: an exact consecutive repetition with a zero
// elaborated bound has one empty match at every sampling event.  The operand
// is deliberately false and the declaration default is deliberately nonzero,
// so neither an ordinary Boolean match nor parse-time default folding can
// produce the expected count.
module cover_parameter_exact_zero_checker #(
  parameter int K = 6
) (
  input logic clk,
  input logic a
);
  zero: cover property (@(posedge clk) a[*K]);
endmodule

module sv_cover_parameter_exact_zero;
  logic clk = 0;
  logic a = 0;

  cover_parameter_exact_zero_checker #(.K(0)) dut (.*);

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    tick();
    tick();
    tick();

    if (dut._ivl_sva0_cnt0 !== 3) begin
      $display("FAILED: [*0] cover count was %0d, expected 3",
               dut._ivl_sva0_cnt0);
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish;
  end
endmodule
