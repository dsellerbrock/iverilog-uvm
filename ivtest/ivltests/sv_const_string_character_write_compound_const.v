module sv_const_string_character_write_compound_const;
  function automatic string compound(input string text);
    byte reference;
    reference = text[0];
    reference /= 258;
    text[0] /= 258;
    if (reference != 0 || text != "ABCDEFGHIJ\200") return "DIV_BAD";
    text[1] += 32'sh101;
    text[2] -= -32'sd1;
    text[3] *= 32'd3;
    text[4] %= 32'd69;
    text[5] &= 8'bx;
    text[6] |= 32'h100;
    text[7] ^= 32'h100;
    text[8] <<= 9;
    text[9] >>= 1;
    text[10] >>>= 1;
    return text;
  endfunction
  localparam string VALUE = compound("ABCDEFGHIJ\200");
  if (VALUE != "ACD\314EFGHI%\300") begin : wrong_constant_result
    nonexistent_compound_string_result fail();
  end
endmodule
