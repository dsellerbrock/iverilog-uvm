class signed_property_item;
  int value;
  int unsigned unsigned_value;
  function void shift_member();
    value >>>= 2;
  endfunction
endclass
module sv_property_compound_signed;
  signed_property_item h;
  int scalar;
  initial begin
    h = new;
    h.value = -64;
    h.value /= 2;
    if (h.value !== -32) $fatal(1, "signed division");
    h.value %= 7;
    if (h.value !== -4) $fatal(1, "signed remainder");
    h.value = -64;
    h.value >>>= 2;
    if (h.value !== -16) $fatal(1, "signed arithmetic shift");
    h.shift_member();
    if (h.value !== -4) $fatal(1, "implicit receiver signed shift");
    h.value = -64;
    h.value >>= 2;
    if (h.value !== 32'h3fff_fff0) $fatal(1, "logical shift");
    h.value = -64;
    h.value /= 32'd2;
    if (h.value !== 32'h7fff_ffe0) $fatal(1, "unsigned RHS division");
    h.unsigned_value = 32'hffff_ffc0;
    h.unsigned_value /= 2;
    if (h.unsigned_value !== 32'h7fff_ffe0) $fatal(1, "unsigned property division");
    h.unsigned_value = 32'hffff_ffc0;
    h.unsigned_value >>>= 2;
    if (h.unsigned_value !== 32'h3fff_fff0) $fatal(1, "unsigned property shift");
    h.value = -64;
    h.value[31:0] >>>= 2;
    if (h.value !== 32'h3fff_fff0) $fatal(1, "unsigned full part select");
    scalar = -64;
    scalar /= 2;
    scalar >>>= 2;
    if (scalar !== -8) $fatal(1, "ordinary signed variable");
    $display("PASSED");
  end
endmodule
