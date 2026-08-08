// An NBA inside a function is legal only when its target does not have
// automatic lifetime (IEEE 1800-2017 10.4.2 and 13.4.4).
module sv_function_nba_automatic_fail;
  function automatic void bad();
    logic local_value;
    local_value <= 1'b1;
  endfunction

  initial bad();
endmodule
