module sv_std_randomize_fixed_array_with_fail;
  bit [31:0] words[8];
  initial begin
    if (std::randomize(words) with { words[0] == 32'h12345678; })
      $fatal(1, "unsupported constrained array call was compiled");
  end
endmodule
