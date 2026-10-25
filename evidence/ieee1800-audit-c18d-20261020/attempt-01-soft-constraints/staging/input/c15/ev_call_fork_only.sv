module t; event done; task trigger(input int ev); endtask initial begin fork @done; #1 trigger(0); join end endmodule
