program pg;
  initial begin
    #5 $display("program completed");
  end
endprogram

module sv_exit_module_origin;
  pg p();

  initial begin
    #1 $display("module calls exit");
    $exit;
  end

  initial begin
    #20 $display("late module process");
  end
endmodule
