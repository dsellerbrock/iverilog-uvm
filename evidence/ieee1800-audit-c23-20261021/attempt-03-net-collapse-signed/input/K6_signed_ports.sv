module k6a(input [3:0] a); initial begin #1; $display("K6a %0d", a); end endmodule
module k6b(input signed [3:0] a); initial begin #1; $display("K6b %0d", a); end endmodule
module k6c(input signed [7:0] a); initial begin #1; $display("K6c %0d", a); end endmodule
module k6d(input signed [7:0] a); initial begin #1; $display("K6d %0d", a); end endmodule
module top;
    logic signed [3:0] s;
    logic [3:0] u;
    initial begin s = -1; u = 4'hf; end
    k6a a(s); k6b b(u); k6c c(s); k6d d(u);
endmodule
