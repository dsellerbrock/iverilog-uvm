extern module ea #(parameter size = 8, parameter type TP = logic [7:0]) (input [size:0] a, output TP b);
module ea(.*); assign b = a[7:0]; endmodule
module top; wire [8:0] a=9'h1A5; wire [7:0] b; ea aa(a,b); initial #1 $display("EXTP %h",b); endmodule
