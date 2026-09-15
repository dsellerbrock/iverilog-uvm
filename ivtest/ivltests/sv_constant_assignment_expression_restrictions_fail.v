module test;
  int outside=10;
  function automatic int assign_nonlocal; int j; j=(outside=5); return j; endfunction
  function automatic int inc_nonlocal; return outside++; endfunction
  function automatic int inc_ref(ref int value); return value++; endfunction
  localparam int A=assign_nonlocal();
  localparam int B=inc_nonlocal();
  localparam int C=inc_ref(outside);
endmodule
