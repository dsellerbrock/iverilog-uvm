package d9_pkg;
  int gv = 27;
  function automatic int read_default(input int x = gv); return x; endfunction
endpackage
module d9_package_default_scope;
  int gv = 99;
  initial $display("D9 value=%0d", d9_pkg::read_default());
endmodule
