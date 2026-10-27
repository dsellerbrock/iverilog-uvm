module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  int a, b, c, x, n, data; time t0; bit clk = 0; bit [3:0] ucnt = 4'd13; int scnt = -3; logic [3:0] xc = 4'bx;
  always #5 clk = ~clk;
  initial begin
    b = 1; fork a = #5 b; #2 b = 2; join
    chk("9.4.5.rhs_sampled_before_delay", a == 1 && $time == 5);
    a = 3; b = 4; fork a = #5 b; b = #5 a; join
    chk("9.4.5.data_swap", a == 4 && b == 3);
    c = 1; fork a = @(posedge clk) c; begin #1 c = 99; end join
    chk("9.4.5.event_rhs_sampled_at_encounter", a == 1 && $time == 15);
    b = 5; c = 6; fork a = @(posedge clk) b; b = @(posedge clk) c; join
    chk("9.4.5.data_shift", a == 5 && b == 6);
    t0 = $time; a = repeat (3) @(posedge clk) c;
    chk("9.4.5.repeat_3", ($time - t0) == 30 && a == 6);
    t0 = $time; x = repeat (scnt) @(posedge clk) 1; chk("9.4.5.repeat_negative", $time == t0 && x == 1);
    t0 = $time; x = repeat (0) @(posedge clk) 2; chk("9.4.5.repeat_zero", $time == t0 && x == 2);
    t0 = $time; x = repeat (ucnt) @(posedge clk) 3; chk("9.4.5.repeat_unsigned_13", ($time - t0) == 130);
    n = 2; t0 = $time; fork x = repeat (n) @(posedge clk) 4; #1 n = 9; join
    chk("9.4.5.repeat_count_once", ($time - t0) == 20 && x == 4);
    a = 0; data = 8; a <= #5 data; chk("9.4.5.nba_delay_nonblocking", a == 0); #1 data = 9;
    #5 chk("9.4.5.nba_delay_rhs_at_encounter", a == 8);
    a = 0; data = 11; a <= repeat (5) @(posedge clk) data; #1 data = 12;
    #200 chk("9.4.5.nba_repeat_assigns_encounter_value", a == 11);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
