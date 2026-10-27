`timescale 1ns/1ps
module w6_join_any_child_remains;
  time t0;
  initial begin
    t0 = $time;
    fork
      #5;
      #40;
    join_any
    wait fork;
    $display("W6 wait fork returned at %0d", $time - t0);
    $finish;
  end
endmodule
