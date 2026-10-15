module sv_wait_order_target;
  event first, second;

  initial
    wait_order(first, second)
      $display("ordered");
    else
      $display("out-of-order");
endmodule
