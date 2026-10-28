module top;
  import "DPI-C" pure p_c = function int p(input int x);
  import "DPI-C" context c_c = function int c(input int x);
  import "DPI" function int d(input int x);
  export "DPI-C" function e;
  function int e(input int x); return x; endfunction
  initial begin
    $display("PASSED");
  end
endmodule
