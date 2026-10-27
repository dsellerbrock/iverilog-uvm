`timescale 1ns/1ps
module w4_child_already_finished;
  time t0;
  initial begin
    t0 = $time;
    fork #5; join_none
    #10;
    wait fork;
    $display("W4 wait fork returned at %0d", $time - t0);
    $finish;
  end
endmodule
