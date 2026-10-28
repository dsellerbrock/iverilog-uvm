module test;
  import "DPI-C" pure function int c_valid(input int x);
  import "DPI-C" pure function int c_output(output int x);
  import "DPI-C" pure function int c_inout(inout int x);
  import "DPI-C" pure function void c_void(input int x);
endmodule
