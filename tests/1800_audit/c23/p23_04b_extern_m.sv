extern module m(a,b,c,d);
module m(.*); input a,b,c; output d; assign d = a & b & c; endmodule
module top; wire a=1,b=1,c=1,d; m mm(a,b,c,d); initial #1 $display("EXTM %b",d); endmodule
