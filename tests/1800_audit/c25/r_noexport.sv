interface ie; extern forkjoin task t(); initial #1 begin t; $display("AFTER"); end endinterface
module top; ie i(); endmodule
