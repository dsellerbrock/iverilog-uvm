`timescale 1ns/1ps
module w5_child_does_not_wait_for_sibling;
  event c1_done;
  initial begin
    fork
      begin : c1
        fork #30; join_none
        wait fork;
        $display("W5 C1 wait fork returned at %0d", $time);
        -> c1_done;
      end
      begin : c2
        #100;
        $display("W5 sibling C2 finished at %0d", $time);
      end
    join_none
    @c1_done;
    $finish;
  end
endmodule
