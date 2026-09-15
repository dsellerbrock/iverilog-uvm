module sv_const_string_array_method_external_fail;
  string words[1];
  function automatic int folded;
    words[0].putc(0, "Z");
    return 1;
  endfunction
  localparam int VALUE = folded();
endmodule
