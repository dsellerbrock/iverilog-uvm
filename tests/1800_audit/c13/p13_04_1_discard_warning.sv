module top;
  function int nv(); return 1; endfunction
  initial begin nv(); void'(nv()); $display("DONE"); end
endmodule
