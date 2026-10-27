module sv_issue877_module;
  task touch;
  endtask
  function integer value;
    value = 2;
  endfunction
endmodule

program sv_issue877_peer;
  task touch;
  endtask
  function integer value;
    value = 3;
  endfunction
endprogram

program sv_issue877_program;
  task touch;
  endtask
  function integer value;
    value = 4;
  endfunction
  initial begin
    touch();
    sv_issue877_peer.touch();
    sv_issue877_module.touch();
    if (value() + sv_issue877_peer.value() + sv_issue877_module.value() != 9)
      $fatal(1, "program calls returned wrong values");
    $display("PASSED");
  end
endprogram

module top;
  initial begin
    sv_issue877_module.touch();
    if (sv_issue877_module.value() != 2)
      $fatal(1, "module calls returned wrong value");
  end
endmodule
