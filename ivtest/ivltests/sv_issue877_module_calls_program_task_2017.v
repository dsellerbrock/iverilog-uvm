program sv_issue877_program;
  task hello;
  endtask
endprogram

module top;
  initial sv_issue877_program.hello();
endmodule
