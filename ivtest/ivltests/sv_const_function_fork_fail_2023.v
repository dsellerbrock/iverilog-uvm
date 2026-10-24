module sv_const_function_fork_fail_2023;
  function int cf(int a);
    fork join_none
    return a;
  endfunction

  localparam int P = cf(2);
endmodule
