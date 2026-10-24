module t; event done; task trigger(event ev); -> ev; endtask initial begin fork @done; #1 trigger(done); join $display("E2 %0t", $time); end endmodule
