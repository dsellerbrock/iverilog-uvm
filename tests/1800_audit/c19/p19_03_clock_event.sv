module top;
  bit clk; bit [1:0] e;
  covergroup c1 @(posedge clk); coverpoint e { bins v[] = {[0:3]}; } endgroup
  covergroup c2 @(posedge clk); option.at_least = 2; coverpoint e { bins v[] = {[0:3]}; } endgroup
  c1 g1 = new; c2 g2;
  initial begin
    e = 1; #1 clk = 1; #1 clk = 0; e = 2; #1 clk = 1; #1 clk = 0;
    $display("%s 19.3.clocking_event_samples cov=%f", (g1.get_inst_coverage() > 49.9 && g1.get_inst_coverage() < 50.1) ? "PASS" : "FAIL", g1.get_inst_coverage());
    g2 = new; e = 3; #1 clk = 1; clk = 0; #0 clk = 1; #1;
    $display("%s 19.3.multiple_events_one_timestep_sample_twice cov=%f", (g2.get_inst_coverage() > 24.9 && g2.get_inst_coverage() < 25.1) ? "PASS" : "FAIL", g2.get_inst_coverage());
  end
endmodule
