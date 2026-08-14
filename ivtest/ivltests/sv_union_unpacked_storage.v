module test;
  typedef union {
    bit   [7:0] byte_value;
    bit   [3:0] nibble;
    logic [7:0] four_state;
  } union_t;

  union_t value;
  union_t copy;

  function automatic union_t relay(input union_t arg);
    relay = arg;
  endfunction

  initial begin
    value.byte_value = 8'h8c;
    if (value.nibble !== 4'hc || value.four_state !== 8'h8c)
      $fatal(1, "wide-to-narrow alias failed: %h/%b",
             value.nibble, value.four_state);

    value.nibble = 4'h5;
    if (value.byte_value !== 8'h05 || value.four_state !== 8'h05)
      $fatal(1, "narrow-to-wide alias failed: %h/%b",
             value.byte_value, value.four_state);

    value.four_state = 8'b10xz_0110;
    if (value.four_state !== 8'b10xz_0110)
      $fatal(1, "four-state view lost X/Z: %b", value.four_state);
    if (value.byte_value !== 8'b1000_0110)
      $fatal(1, "two-state alias did not coerce X/Z: %b",
             value.byte_value);

    copy = relay(value);
    copy.nibble = 4'hd;
    if (copy.byte_value !== 8'h0d)
      $fatal(1, "copied union alias failed: %h", copy.byte_value);
    if (value.byte_value !== 8'h86)
      $fatal(1, "union copy aliased the source: %h", value.byte_value);

    $display("UNPACKED byte=%h nibble=%h logic=%b copy=%h",
             value.byte_value, value.nibble, value.four_state,
             copy.byte_value);
    $display("PASSED");
  end
endmodule
