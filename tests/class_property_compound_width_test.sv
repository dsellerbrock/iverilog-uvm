class compound_width_holder;
  bit [8:0] value;

  function void clear_wide_bits(bit [31:0] clear_mask);
    value &= ~clear_mask;
  endfunction
endclass

module class_property_compound_width_test;
  initial begin
    compound_width_holder holder;
    bit [8:0] narrow;
    bit [31:0] wide;
    holder = new;

    holder.value = 9'h1ff;
    holder.clear_wide_bits(32'h0000_0155);
    if (holder.value !== 9'h0aa)
      $fatal(1, "narrow class property &= wide complement gave %h",
             holder.value);

    holder.value = 9'h101;
    holder.clear_wide_bits(32'hffff_fff0);
    if (holder.value !== 9'h001)
      $fatal(1, "compound assignment did not retain the low-width result");

    // Assignment context propagates through unary integral operators before
    // the operation (IEEE 1800-2017 11.8.2), including into a signal load.
    narrow = 9'h100;
    wide = ~narrow;
    if (wide !== 32'hffff_feff)
      $fatal(1, "context-sized unary complement gave %h", wide);
    wide = -narrow;
    if (wide !== 32'hffff_ff00)
      $fatal(1, "context-sized unary negation gave %h", wide);

    $display("PASS: compound assignment and unary context sizing");
  end
endmodule
