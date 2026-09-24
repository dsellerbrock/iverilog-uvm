`timescale 1ns/1ps
module pure_checker_controls;
  bit clk = 0, trigger = 0, reset_ok = 0;
  bit nba_value = 0;
  int vac_fail = 0, pass_fail = 0, live_fail = 0, disabled_fail = 0, nba_fail = 0;
  always #5 clk = ~clk;
  always @(posedge clk) if ($time == 25) nba_value <= 1;
  function automatic bit mismatch();
`ifdef IMPURE
    $display("INNER mismatch time=%0t", $time);
`endif
    return 0;
  endfunction
  function automatic bit good(); return 1; endfunction
  function automatic bit nba_check();
`ifdef IMPURE
    if (!nba_value) $display("INNER nba time=%0t", $time);
`endif
    return nba_value;
  endfunction
  a_vac: assert property (@(posedge clk) 1'b0 |=> mismatch())
    else begin vac_fail++; $display("OUTER vac"); end
  a_pass: assert property (@(posedge clk) trigger |=> good())
    else begin pass_fail++; $display("OUTER pass"); end
  a_live: assert property (@(posedge clk) trigger |=> mismatch())
    else begin live_fail++; $display("OUTER live"); end
  a_disabled: assert property (@(posedge clk) disable iff (!reset_ok) trigger |=> mismatch())
    else begin disabled_fail++; $display("OUTER disabled"); end
  a_nba: assert property (@(posedge clk) trigger |=> nba_check())
    else begin nba_fail++; $display("OUTER nba"); end
  initial begin
    #12 trigger = 1;
    #10 trigger = 0;
    #30;
    $display("COUNTS vac=%0d pass=%0d live=%0d disabled=%0d nba=%0d value=%0d", vac_fail, pass_fail, live_fail, disabled_fail, nba_fail, nba_value);
    $finish;
  end
endmodule
