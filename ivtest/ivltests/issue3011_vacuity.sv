// IEEE 1800 16.14.8(g,z,af): selected branches determine vacuity.
module issue3011_vacuity;
  bit clk = 0;
  bit a = 0, b = 1;
  int ip, ep, mp, cp, dp, nestedp, controlp, failures;
  always #5 clk = ~clk;

  ai: assert property (@(posedge clk) if (a) b) ip++; else failures++;
  ae: assert property (@(posedge clk) if (a) b else b) ep++; else failures++;
  am: assert property (@(posedge clk) a implies b) mp++; else failures++;
  ac: assert property (@(posedge clk) case (a) 1'b1: b; endcase) cp++; else failures++;
  ad: assert property (@(posedge clk) case (a) 1'b1: b; default: b; endcase) dp++; else failures++;
  an: assert property (@(posedge clk) if (b) (if (a) b)) nestedp++; else failures++;
  ax: assert property (@(posedge clk) b) controlp++; else failures++;

  initial begin
    $assertvacuousoff(0);
    #6;
    if (ip != 0 || ep != 1 || mp != 0 || cp != 0 || dp != 1 || nestedp != 0 || controlp != 1 || failures != 0)
      $fatal(1, "false: %0d %0d %0d %0d %0d %0d %0d fail=%0d", ip, ep, mp, cp, dp, nestedp, controlp, failures);
    @(negedge clk) a = 1;
    #6;
    if (ip != 1 || ep != 2 || mp != 1 || cp != 1 || dp != 2 || nestedp != 1 || controlp != 2 || failures != 0)
      $fatal(1, "true: %0d %0d %0d %0d %0d %0d %0d fail=%0d", ip, ep, mp, cp, dp, nestedp, controlp, failures);
    @(negedge clk) begin a = 0; $assertpasson(0); end
    #6;
    if (ip != 2 || ep != 3 || mp != 2 || cp != 2 || dp != 3 || nestedp != 2 || controlp != 3 || failures != 0)
      $fatal(1, "vacuous on: %0d %0d %0d %0d %0d %0d %0d fail=%0d", ip, ep, mp, cp, dp, nestedp, controlp, failures);
    @(negedge clk) begin a = 1; b = 0; end
    #6;
    if (ip != 2 || ep != 3 || mp != 2 || cp != 2 || dp != 3 || nestedp != 3 || controlp != 3 || failures != 6)
      $fatal(1, "failures: %0d %0d %0d %0d %0d %0d %0d fail=%0d", ip, ep, mp, cp, dp, nestedp, controlp, failures);
    $display("PASS");
    $finish;
  end
endmodule
