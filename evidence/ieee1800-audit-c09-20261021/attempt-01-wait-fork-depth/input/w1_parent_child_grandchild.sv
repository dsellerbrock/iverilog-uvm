`timescale 1ns/1ps
module w1_parent_child_grandchild;
  time t0;
  initial begin
    t0 = $time;
    fork
      begin
        #10;
        fork #50; join_none
      end
    join_none
    wait fork;
    $display("W1 wait fork returned at %0d", $time - t0);
    $finish;
  end
endmodule
