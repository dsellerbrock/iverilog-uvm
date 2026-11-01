module sv_std_randomize_fixed_array_with_2023;
  bit [31:0] words[8];
  initial begin
    if (!std::randomize(words) with { words[0] == 32'h12345678; })
      $fatal(1, "constrained array randomize failed");
    if (words[0] !== 32'h12345678)
      $fatal(1, "words[0] = %h, expected 12345678", words[0]);
    $display("PASSED");
    $finish(0);
  end
endmodule
