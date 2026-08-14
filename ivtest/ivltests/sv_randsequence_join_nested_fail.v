module sv_randsequence_join_nested_fail;
  initial begin
    randsequence (main)
      main : rand join left right;
      left : leaf;
      leaf : { $display("BAD left"); };
      right : { $display("BAD right"); };
    endsequence
  end
endmodule
