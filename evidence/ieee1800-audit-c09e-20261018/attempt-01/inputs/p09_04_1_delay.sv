module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  parameter d = 3;
  int e = 4, regr = 2, neg = -1, flagneg = 0;
  time t0;
  logic [3:0] dx = 4'bx, dz = 4'bz;
  initial begin
    #10 chk("9.4.1.delay_10", $time == 10);
    #d chk("9.4.1.delay_parameter", $time == 13);
    #((d+e)/2) chk("9.4.1.delay_expression", $time == 16);
    #regr regr = regr + 1; chk("9.4.1.delay_variable", $time == 18 && regr == 3);
    t0 = $time; #dx chk("9.4.1.x_delay_is_zero", $time == t0);
    #dz chk("9.4.1.z_delay_is_zero", $time == t0);
    fork begin #neg flagneg = 1; end join_none
    #1000 chk("9.4.1.negative_delay_is_huge_unsigned", flagneg == 0 && $time == t0 + 1000);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
