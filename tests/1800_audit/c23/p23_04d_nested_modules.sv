module part1; module and2(input a, b, output z); assign z=a&b; endmodule module or2(input a, b, output z); assign z=a|b; endmodule
 wire x=1, y=0, z1, z2; and2 u1(x,y,z1); or2 u2(x,y,z2); initial #1 $display("NEST1 %b %b", z1, z2); endmodule
module part2; module and2(input a, b, output z); assign z=a^b; endmodule
 wire x=1, y=0, z1; and2 u1(x,y,z1); initial #1 $display("NEST2 %b", z1); endmodule
module host; module lonely; initial $display("LONELY"); endmodule module hasports(input a); initial $display("NOPE"); endmodule endmodule
module top; part1 p1(); part2 p2(); host h(); endmodule
