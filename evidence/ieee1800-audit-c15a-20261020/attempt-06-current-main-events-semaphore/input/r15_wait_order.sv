module p;
 event a, b;
 int result;
 initial begin wait_order(a, b) result=1; else result=-1; end
 initial begin #1 -> a; #1 -> b; end
 initial begin #3 $display("RESULT result=%0d", result); $finish; end
endmodule
