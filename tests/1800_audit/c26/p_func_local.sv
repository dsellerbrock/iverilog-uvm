package p; function int f(); return 1; endfunction endpackage
module top;
  int x;
  if (1) begin : b
    initial x = f();
    import p::*;
    function int f(); return 2; endfunction
  end
  initial #1 $display("P4 %0d", x);
endmodule
