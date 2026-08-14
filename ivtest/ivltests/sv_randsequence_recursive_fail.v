module sv_randsequence_recursive_fail;
  initial begin
    randsequence (main)
      main : again;
      again : main;
    endsequence
  end
endmodule
