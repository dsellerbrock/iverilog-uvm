module issue2999_named_property_not;
  bit clk = 0;
  logic a = 0;
  int failures = 0, wrong_time = 0;
  always #5 clk = ~clk;

  property p; a; endproperty
  property alias_p; p; endproperty
  n: assert property (@(posedge clk) not (p))
       ; else begin failures++; if ($time != 15) wrong_time++; end
  n_alias: assert property (@(posedge clk) not (alias_p))
       ; else begin failures++; if ($time != 15) wrong_time++; end

  initial begin
    @(negedge clk) a = 1;
    @(negedge clk) a = 1'bx;
    @(negedge clk) a = 0;
    @(posedge clk); #1;
    if (failures != 2 || wrong_time != 0)
      $display("FAIL failures=%0d wrong_time=%0d", failures, wrong_time);
    else
      $display("PASSED");
    $finish;
  end
endmodule
