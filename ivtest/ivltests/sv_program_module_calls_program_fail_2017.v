program sv_program_module_calls_program_fail_program;
  task say_hello;
    $display("HELLO");
  endtask
endprogram

module sv_program_module_calls_program_fail_module;
  initial sv_program_module_calls_program_fail_program.say_hello();
endmodule
