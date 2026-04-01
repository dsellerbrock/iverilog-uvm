module test;
  class waiter_t;
    event trigger;
  endclass

  waiter_t w;

  initial begin
    w = new;
    fork
      begin
        #1 ->w.trigger;
      end
      begin
        @w.trigger;
      end
    join

    $display("PASSED");
  end
endmodule
