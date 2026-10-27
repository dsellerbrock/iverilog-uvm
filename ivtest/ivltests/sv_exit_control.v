// IEEE 1800-2017/2023 20.2 and 24.7: $exit is a program control task.
program sv_exit_control_program;
  initial begin
    #1;
    $display("PROGRAM exit");
    $exit;
    $display("FAIL: program continued after $exit");
  end

  initial begin
    #5;
    $display("PROGRAM peer completed");
  end
endprogram

module sv_exit_control;
  sv_exit_control_program p();

  initial begin
    #2;
    $display("MODULE exit");
    $exit;
    $display("MODULE continued after ignored $exit");
  end

  initial begin
    #20;
    $display("FAIL: late module process ran");
  end
endmodule
