module dut(input a, output b); assign b=a; endmodule
module top; reg a=0; wire b; dut u(a,b); initial begin $dumpports(); #5 a=1; #5 $finish; end endmodule
