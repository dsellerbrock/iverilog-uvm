module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  logic clk = 0, a = 0, b = 0, c = 0; time t_wait; bit tr_at, tr_later;
  sequence abc; @(posedge clk) a ##1 b ##1 c; endsequence
  always #5 clk = ~clk;
  initial begin #1 a = 1; #10 b = 1; #10 c = 1; end
  initial begin
    wait (abc.triggered);
    t_wait = $time; tr_at = abc.triggered;
    #1 tr_later = abc.triggered;
    chk("9.4.4.wait_triggered_unblocks_at_end_point", t_wait == 25);
    chk("9.4.4.triggered_true_in_the_time_step", tr_at == 1'b1);
    chk("9.4.4.triggered_false_after_time_advances", tr_later == 1'b0);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
