module sv_array_string_character_compound_ops;
  string values[1];
  initial begin
    values[0]="\310\201\177";
    values[0][0] /= 2;
    values[0][1] %= 8'h7f;
    values[0][2] += 16'h0101;
    values[0][2] *= 2;
    values[0][0] >>>= 2;
    values[0][1] >>= 1;
    values[0][1] |= 8'h80;
    values[0][2] ^= 8'hff;
    values[0][2] &= 8'h7f;
    values[0][2] -= 1;
    values[0][0] <<= 1;
    values[0][0] <<<= 1;
    if(values[0]!="\344\201\176") $fatal(1,"ops=%h",values[0]);
    $display("PASSED");
  end
endmodule
