module sv_ref_argument_static_sub_fail;
  function static void explicit_static(ref int value);
  endfunction

  function void implicit_static(ref int value);
  endfunction
endmodule
