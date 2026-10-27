`timescale 1ns/1ps
module w2_called_task_child;
  time t0;
  task automatic t;
    fork #20; join_none
  endtask
  initial begin
    t0 = $time;
    t();
    wait fork;
    $display("W2 wait fork returned at %0d", $time - t0);
    $finish;
  end
endmodule
