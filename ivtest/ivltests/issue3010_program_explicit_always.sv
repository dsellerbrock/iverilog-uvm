program issue3010_program_explicit_always(input bit clk);
  always assert property (@(posedge clk) 1'b1);
endprogram
