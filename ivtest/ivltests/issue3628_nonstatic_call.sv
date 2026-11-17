class issue3628_target;
  function int f(); return 1; endfunction
endclass
module issue3628_nonstatic_call;
  initial $display("%0d", issue3628_target::f());
endmodule
