program sv_issue877_program;
  function integer value;
    value = 1;
  endfunction
endprogram

module top;
  integer result;
  initial result = sv_issue877_program.value();
endmodule
