class semaphore;
  int tag = 42;
endclass

module p26_07_std_shadow;
  semaphore us;
  initial begin
    us = new;
    $display("S4 %0d", us.tag);
  end
endmodule
