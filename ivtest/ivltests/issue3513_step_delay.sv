module finer_precision;
  timeunit 1fs/1fs;
endmodule

module issue3513_step_delay;
  timeunit 1ps/1ps;
  logic a = 0;
  wire #1step w = a;
  wire c, g;
  assign #1step c = a;
  buf #1step u(g, a);
  finer_precision precision_scope();

  task check(input logic expected);
    if ({w, c, g} !== {3{expected}}) begin
      $display("FAIL: time=%0t expected=%b actual=%b", $time, expected, {w,c,g});
      $finish;
    end
  endtask

  initial begin
    #2;
    check(0);
    a = 1;
    #0 check(0);
    #1step;
    #0 check(1);
    a = 0;
    #0 check(1);
    #1step;
    #0 check(0);
    $display("PASS");
  end
endmodule
