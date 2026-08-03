// IEEE 1800-2017 9.2.2.2/12.8: break and continue are control-flow leaves;
// they contribute no data dependencies while an always_comb sensitivity set
// is derived. The scanner previously reported internal compiler errors.
module always_comb_break_sensitivity_test;
  logic [1:0] values = 0;
  logic found;

  always_comb begin
    found = 0;
    for (int index = 0; index < 2; index++) begin
      if (!values[index]) continue;
      found = 1;
      break;
    end
  end

  initial begin
    #1;
    if (found !== 0) $fatal(1, "bad initial result");
    values = 2'b10;
    #1;
    if (found !== 1) $fatal(1, "always_comb missed input change");
    values = 0;
    #1;
    if (found !== 0) $fatal(1, "always_comb missed clear");
    $display("ALWAYS_COMB BREAK SENSITIVITY TEST: PASS");
    $finish(0);
  end
endmodule
