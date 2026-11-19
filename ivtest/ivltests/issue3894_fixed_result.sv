module issue3894_fixed_result;
  int dst [2], hit [2], miss [2];
  function automatic int f();
    return 1;
  endfunction
  initial dst = f() matches .* ? hit : miss;
endmodule
