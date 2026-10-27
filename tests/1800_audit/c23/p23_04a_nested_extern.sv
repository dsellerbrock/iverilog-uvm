extern module m(a,b,c,d);
extern module ea #(parameter size = 8, parameter type TP = logic [7:0]) (input [size:0] a, output TP b);
module m(.*); input a,b,c; output d; assign d = a & b & c; endmodule
module ea(.*); assign b = a[7:0]; endmodule
module part1; module and2(input a, b, output z); assign z=a&b; endmodule module or2(input a, b, output z); assign z=a|b; endmodule
 wire x=1, y=0, z1, z2; and2 u1(x,y,z1); or2 u2(x,y,z2); initial #1 $display("NEST1 %b %b", z1, z2); endmodule
module part2; module and2(input a, b, output z); assign z=a^b; endmodule
 wire x=1, y=0, z1; and2 u1(x,y,z1); initial #1 $display("NEST2 %b", z1); endmodule
module host; module lonely; initial $display("LONELY"); endmodule module hasports(input a); initial $display("NOPE"); endmodule endmodule
module top; wire a=1,b=1,c=1,d; wire [8:0] ea_a=9'h1A5; wire [7:0] ea_b; m mm(a,b,c,d); ea aa(ea_a, ea_b);
 initial #1 $display("EXT %b %h", d, ea_b); endmodule
