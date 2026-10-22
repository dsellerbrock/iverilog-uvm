class C; int p; endclass
module m; C c = new; assign c.p = 1; endmodule
