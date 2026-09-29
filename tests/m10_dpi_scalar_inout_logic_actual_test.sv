// Mirrors OTBN's otbn_model_check(model_handle, check_mismatch_d): the DPI
// formal is two-state bit, while the actual and following NBA are logic.
module m10_dpi_scalar_inout_logic_actual_test;
  import "DPI-C" context function int otbn_model_check(chandle model,
                                                         inout bit mismatch);
  chandle model_handle;
  bit clk;
  logic mismatch_d, mismatch_q, check_ok;

  always_ff @(posedge clk) begin
    check_ok <= (otbn_model_check(model_handle, mismatch_d) == 0);
    mismatch_q <= mismatch_d;
  end

  initial begin
    #1 clk = 1;
    #1;
    if (check_ok !== 1 || mismatch_d !== 1 || mismatch_q !== 1)
      $fatal(1, "DPI bit formal copy-out: %b %b %b",
             check_ok, mismatch_d, mismatch_q);
    $display("PASS m10_dpi_scalar_inout_logic_actual_test");
  end
endmodule
