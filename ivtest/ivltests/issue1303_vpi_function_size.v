module top;
  function int f(input int x);
    f = x;
  endfunction

  function void vf();
  endfunction

  initial $display("PASSED");
endmodule
