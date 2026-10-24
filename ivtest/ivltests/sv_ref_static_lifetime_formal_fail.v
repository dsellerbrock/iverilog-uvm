module sv_ref_static_lifetime_formal_fail;
  function static void explicit_static_function(ref int value);
  endfunction

  function void implicit_static_function(ref int value);
  endfunction

  task static explicit_static_task(ref int value);
  endtask

  task implicit_static_task(ref int value);
  endtask
endmodule
