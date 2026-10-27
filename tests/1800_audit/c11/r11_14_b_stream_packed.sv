module m; logic [43:0] v = {11'd1, 11'd2, 11'd3, 11'd4}; logic [10:0] p1, p2, p3, p4; initial begin {>>{p1,p2,p3,p4}} = v; $display("B %0d %0d %0d %0d", p1, p2, p3, p4); end endmodule
