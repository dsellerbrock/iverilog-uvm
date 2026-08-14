module test;
  typedef union tagged packed {
    bit [6:0] First;
    bit [6:0] Second;
  } value_t;

  value_t value;
  value_t copy;

  initial begin
    if ($bits(value) != 8 || $bits(value_t) != 8)
      $fatal(1, "tagged packed width is %0d/%0d",
             $bits(value), $bits(value_t));

    value = tagged First(7'h55);
    if (value !== 8'h55 || value.First !== 7'h55)
      $fatal(1, "first tag encoding/value failed: %b", value);

    value = tagged Second(7'h2a);
    if (value !== 8'haa || value.Second !== 7'h2a)
      $fatal(1, "second tag encoding/value failed: %b", value);

    copy = value;
    if (copy !== 8'haa || copy.Second !== 7'h2a)
      $fatal(1, "tagged packed copy failed: %b", copy);

    $display("PACKED first=%b second=%b copy=%b", 8'h55, value, copy);
    $display("PASSED");
  end
endmodule
