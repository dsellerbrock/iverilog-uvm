`timescale 1ns/1ps
module w7_uvm_forever_monitor_grandchild;
  integer ticks = 0;
  time t0;
  initial begin
    t0 = $time;
    fork
      begin
        fork forever begin #7; ticks++; end join_none
        #3;
      end
    join_none
    wait fork;
    $display("W7 wait fork returned at %0d ticks=%0d", $time - t0, ticks);
    $finish;
  end
endmodule
