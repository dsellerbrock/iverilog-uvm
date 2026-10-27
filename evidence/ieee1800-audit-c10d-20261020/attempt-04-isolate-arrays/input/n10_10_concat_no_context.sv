module n10_10_concat_no_context;
  int q2[$];
  initial begin
    q2 = '{7, 8};
    $display("%0d", {q2, 9}.size());
  end
endmodule
