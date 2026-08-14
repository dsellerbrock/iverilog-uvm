module sv_randsequence_nonconstant_actual_fail;
  int source = 7;
  initial begin
    randsequence (main)
      main : add(source);
      void add(input int value) : { $display("BAD %0d", value); };
    endsequence
  end
endmodule
