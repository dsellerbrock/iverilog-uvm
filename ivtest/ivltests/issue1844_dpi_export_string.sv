module tb;
  import "DPI-C" context function int c_go();
  function void x_s(string s, output string t); t = {s, "!"}; endfunction
  export "DPI-C" function x_s;
  initial void'(c_go());
endmodule
