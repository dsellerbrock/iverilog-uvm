module sv_randsequence_value_return_fail;
  initial begin
    randsequence (main)
      main : value;
      int value : { return 1; };
    endsequence
  end
endmodule
