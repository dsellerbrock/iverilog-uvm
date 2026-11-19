`timescale 1ns/1ps
module main;
  bit clk;
  logic [127:0] b;
  int tick, settled;
  int delayed_pass, delayed_fail, goto_pass, goto_fail;

  delayed: assert property (@(posedge clk) nexttime[2] b[=2:4])
    begin
      if (settled != tick) $fatal(1, "pass action ran before NBA");
      delayed_pass++;
    end
    else begin
      if (settled != tick) $fatal(1, "fail action ran before NBA");
      delayed_fail++;
    end

  aligned: assume property (@(posedge clk) nexttime[0] (@(posedge clk) b[->1:$]))
    goto_pass++; else goto_fail++;

  initial begin
`ifdef CHECK_START_TIMES
    #0 $issue3793_watch;
`endif
    for (tick = 1; tick <= 47; tick++) begin
      case (tick)
        41, 43: b = {1'b1, 126'b0, 1'bx};
        45: b = {127'b0, 1'bx};
        47: b = {127'b0, 1'bz};
        default: b = 0;
      endcase
      #1 clk = 1;
      b <= 0;
      settled <= tick;
      #1 clk = 0;

      if (delayed_pass != (tick == 43 ? 39 : 0) ||
          delayed_fail != (tick == 45 ? 4 : tick == 47 ? 2 : 0) ||
          goto_pass != (tick == 41 ? 41 : tick == 43 ? 2 : 0) ||
          goto_fail != (tick == 45 || tick == 47 ? 2 : 0))
        $fatal(1, "tick %0d delayed=%0d/%0d goto=%0d/%0d",
               tick, delayed_pass, delayed_fail, goto_pass, goto_fail);
      if (delayed_pass || delayed_fail || goto_pass || goto_fail)
        $display("tick %0d delayed=%0d/%0d goto=%0d/%0d",
                 tick, delayed_pass, delayed_fail, goto_pass, goto_fail);
      delayed_pass = 0;
      delayed_fail = 0;
      goto_pass = 0;
      goto_fail = 0;
    end
`ifdef CHECK_START_TIMES
    $issue3793_check;
`endif
    $display("PASSED");
  end
endmodule
