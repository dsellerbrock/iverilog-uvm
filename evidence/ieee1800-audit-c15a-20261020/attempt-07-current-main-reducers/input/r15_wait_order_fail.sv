module p15_wait_order_fail;
 event a, b;
 initial wait_order(a, b);
 initial begin #1 -> b; #1 -> a; #1 $display("SURVIVED"); end
endmodule
