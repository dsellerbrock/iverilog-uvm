module sv_function_own_name_duplicate;
  function automatic int duplicate;
    int duplicate;
    duplicate = 1;
  endfunction

  initial $display("%0d", duplicate());
endmodule
