module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  logic enable; int a, b = 7, c, d = 9; time t0; logic [3:0] v = 4'bx; logic ready;
  logic p1 = 0, q1 = 0;
  initial begin
    enable = 1; t0 = $time;
    fork begin #7 enable = 0; end join_none
    begin wait (!enable) #10 a = b; #10 c = d; end
    chk("9.4.3.wait_blocks_until_true", a == 7 && c == 9 && ($time - t0) == 27);
    t0 = $time; a = 0; c = 0;
    begin wait (!enable) #10 a = b; #10 c = d; end
    chk("9.4.3.wait_true_on_entry_no_extra_delay", ($time - t0) == 20 && a == 7 && c == 9);
    t0 = $time; wait (1); wait (1'b1);
    chk("9.4.3.wait_true_constant_zero_time", $time == t0);
    fork begin #4 v = 4'b0001; end join_none
    t0 = $time; wait (v);
    chk("9.4.3.wait_x_is_not_true", ($time - t0) == 4);
    t0 = $time;
    fork begin #2 p1 = 1; #3 q1 = 1; end join_none
    wait (p1 && q1);
    chk("9.4.3.wait_reevaluates_on_any_operand", ($time - t0) == 5);
    ready = 1; t0 = $time; wait (ready);
    chk("9.4.3.wait_level_not_edge", $time == t0);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
