module issue3802_multiclock_vacuity;
  bit [3:0] clk;
  bit abort_attempt;
  bit b, b_tail, c, d;
  int batch, local_end, coincident, success, failures, resumed;

  check: assert property (@(posedge clk[0]) disable iff (abort_attempt)
                         1'b1 ##1 @(posedge clk[1]) b ##1 b_tail
                         ##1 @(posedge clk[2]) c |=> @(posedge clk[3]) d)
    case ($time)
      8: batch++;
      23: local_end++;
      35: coincident++;
      62: success++;
      100: resumed++;
      default: $fatal(1, "unexpected pass at %0t", $time);
    endcase
  else begin
    if ($time != 77) $fatal(1, "unexpected failure at %0t", $time);
    failures++;
  end

  task automatic tick(input bit [3:0] clocks);
    #2 clk = clocks;
    #1 clk = 0;
  endtask

`ifdef ISSUE3802_VPI
  initial #1 $vac_setup;
`endif

  initial begin
    // Both source attempts reach b on the same clk[1] tick and die.
    tick(4'b0001); // 2
    tick(4'b0001); // 5
    tick(4'b0010); // 8
    tick(4'b0100); // 11
    tick(4'b1000); // 14

    b = 1;
    tick(4'b0001); // 17
    tick(4'b0010); // 20: b matches
    tick(4'b0010); // 23: b_tail misses

    b_tail = 1;
    tick(4'b0001); // 26
    tick(4'b0010); // 29
    tick(4'b0011); // 32: b_tail matches and a new source attempt starts
    b = 0;
    tick(4'b0110); // 35: older attempt misses c, newer attempt misses b

    // Suppress only the vacuous action. The VPI verdict still occurs.
    $assertvacuousoff(0);
    b = 1;
    tick(4'b0001); // 38
    tick(4'b0010); // 41
    tick(4'b0010); // 44
    tick(4'b0100); // 47: c misses

    c = 1;
    d = 1;
    tick(4'b0001); // 50
    tick(4'b0010); // 53
    tick(4'b0010); // 56
    tick(4'b0100); // 59
    tick(4'b1000); // 62: consequent succeeds
    d = 0;
    tick(4'b0001); // 65
    tick(4'b0010); // 68
    tick(4'b0010); // 71
    tick(4'b0100); // 74
    tick(4'b1000); // 77: consequent fails

    // Cancel a partial antecedent between its two local ticks.
    $assertpasson(0);
    tick(4'b0001); // 80
    tick(4'b0010); // 83
    #1 abort_attempt = 1;
    #1 abort_attempt = 0;
    b_tail = 0;
    tick(4'b0010); // 88: canceled attempt must produce no verdict
    tick(4'b0100); // 91
    tick(4'b1000); // 94
    b = 0;
    tick(4'b0001); // 97
    tick(4'b0010); // 100: fresh attempt dies normally

    if (batch != 2 || local_end != 1 || coincident != 2 ||
        success != 1 || failures != 1 || resumed != 1)
      $fatal(1, "wrong counts: batch=%0d local_end=%0d coincident=%0d success=%0d failures=%0d resumed=%0d",
             batch, local_end, coincident, success, failures, resumed);
`ifdef ISSUE3802_VPI
    $vac_dump;
`endif
    $display("PASSED");
    $finish(0);
  end
endmodule
