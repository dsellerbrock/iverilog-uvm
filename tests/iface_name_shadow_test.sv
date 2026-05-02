// Phase 44 repro: when interface instance name == interface type name
// (`clk_rst_if clk_rst_if(...)`), `inst.method()` was being parsed via the
// `expr_primary . IDENTIFIER ()` rule, which silently dropped the receiver,
// turning the call into a bare `method()`. OpenTitan tb.sv hits this for
// `clk_rst_if.set_active()` -- without the receiver the function never runs
// and the clock/reset interface stays inactive, hanging every DV test.

interface clk_rst_if;
  bit drive_clk;
  function automatic void set_active(bit val = 1'b1);
    drive_clk = val;
  endfunction
endinterface

module top;
  clk_rst_if clk_rst_if();
  initial begin
    clk_rst_if.set_active();
    #1;
    if (clk_rst_if.drive_clk) $display("PASS");
    else $display("FAIL drive_clk=%b", clk_rst_if.drive_clk);
    $finish;
  end
endmodule
