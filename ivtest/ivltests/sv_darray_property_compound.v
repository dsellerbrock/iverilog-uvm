class compound_item;
  logic [31:0] value[];
  byte unsigned narrow[];
  byte signed signed_value[];
endclass
module sv_darray_property_compound;
  compound_item h, original, replacement;
  int calls, rhs_calls;
  logic [31:0] bad_index;
  function automatic int index_once();
    calls++;
    return 0;
  endfunction
  function automatic int rhs();
    rhs_calls++;
    return 3;
  endfunction
  function automatic int rebind();
    h = replacement;
    return 7;
  endfunction
  initial begin
    h = new;
    h.value = new[2];
    h.narrow = new[1];
    h.signed_value = new[1];
    h.value[0] = 'hf0;
    h.value[1] = 'h1234;
    h.value[index_once()] |= rhs();
    if (calls != 1 || rhs_calls != 1 || h.value.size() != 2 ||
        h.value[0] !== 'hf3 || h.value[1] !== 'h1234)
      $fatal(1, "selected element/index");
    h.value[0] &= 'h3f;
    h.value[0] ^= 'h12;
    h.value[0] += 5;
    h.value[0] -= 2;
    h.value[0] *= 3;
    h.value[0] /= 4;
    h.value[0] %= 10;
    if (h.value[0] !== 7) $fatal(1, "arithmetic and bitwise");
    h.value[0] <<= 2;
    h.value[0] >>= 1;
    h.value[0] <<<= 1;
    h.value[0] >>>= 2;
    if (h.value[0] !== 7) $fatal(1, "shifts");
    h.narrow[0] = 128;
    h.narrow[0] /= 32'd256;
    if (h.narrow[0] !== 0) $fatal(1, "wide divisor");
    h.narrow[0] = 128;
    h.narrow[0] >>= 32'd256;
    if (h.narrow[0] !== 0) $fatal(1, "wide shift count");
    h.narrow[0] = 255;
    h.narrow[0] += 16'd2;
    if (h.narrow[0] !== 1) $fatal(1, "assignment truncation");
    h.signed_value[0] = -64;
    h.signed_value[0] /= 32'sd2;
    if (h.signed_value[0] !== -8'sd32) $fatal(1, "signed division");
    h.signed_value[0] >>>= 2;
    if (h.signed_value[0] !== -8'sd8) $fatal(1, "signed shift");
    h.signed_value[0] = -1;
    h.signed_value[0] /= 32'd2;
    if (h.signed_value[0] !== 8'd127) $fatal(1, "mixed signedness");
    h.value[-1] += rhs();
    h.value[2] += rhs();
    bad_index = 'x;
    h.value[bad_index] += rhs();
    bad_index = 'z;
    h.value[bad_index] += rhs();
    if (rhs_calls != 5 || h.value.size() != 2 ||
        h.value[0] !== 7 || h.value[1] !== 'h1234)
      $fatal(1, "invalid index side effects or store");
    h.narrow[0] = 1;
    h.narrow[0] += 8'bx;
    if (h.narrow[0] !== 0) $fatal(1, "four-state operand conversion");
    original = h;
    replacement = new;
    replacement.value = new[1];
    replacement.value[0] = 100;
    h.value[0] += rebind();
    if (original.value[0] !== 14 || h != replacement || h.value[0] !== 100)
      $fatal(1, "receiver capture");
    $display("PASSED");
  end
endmodule
