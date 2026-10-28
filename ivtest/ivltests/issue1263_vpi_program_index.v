program p;
  initial begin end
endprogram

module issue1263_vpi_program_index;
  p prog[1:0]();
  p scalar();

  initial begin
    #0;
    $probe_program_index;
    $finish;
  end
endmodule
