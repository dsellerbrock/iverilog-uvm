`timescale 1ns/1ps
module w3_no_children;
  time t0;
  initial begin
    t0 = $time;
    wait fork;
    $display("W3 wait fork returned at %0d", $time - t0);
    $finish;
  end
endmodule
