module top; process p;
  initial begin p = process::self(); p.await(); $display("REACHED_AFTER_AWAIT_SELF"); end
endmodule
