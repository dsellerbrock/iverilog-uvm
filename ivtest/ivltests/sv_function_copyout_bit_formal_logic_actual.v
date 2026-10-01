// A bit inout formal converts its logic actual for copy-in, but copy-out
// must still write the original logic variable before the following NBA.
module sv_function_copyout_bit_formal_logic_actual;
  bit clk;
  logic mismatch_d, mismatch_q, check_ok;

  function automatic int mark(inout bit mismatch);
    mismatch = 1;
    return 0;
  endfunction

  always_ff @(posedge clk) begin
    check_ok <= (mark(mismatch_d) == 0);
    mismatch_q <= mismatch_d;
  end

  initial begin
    #1 clk = 1;
    #1;
    if (check_ok !== 1 || mismatch_d !== 1 || mismatch_q !== 1)
      $fatal(1, "bit formal copy-out: %b %b %b",
             check_ok, mismatch_d, mismatch_q);
    $display("PASSED");
  end
endmodule
