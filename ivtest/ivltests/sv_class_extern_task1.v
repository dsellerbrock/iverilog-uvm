package p;
  class worker;
    int seen;
    extern task bump(int step);
  endclass

  task worker::bump(int step);
    seen += step;
  endtask
endpackage

module test;
  import p::*;

  initial begin
    worker w = new;
    w.bump(7);
    if (w.seen !== 7) begin
      $display("FAIL seen=%0d", w.seen);
      $finish(1);
    end
    $display("PASS");
  end
endmodule
