typedef union soft packed {
  bit [7:0] bytes;
  bit [3:0] low_nibble;
  union soft {
    bit [5:0] six;
    bit [1:0] pair;
  } nested;
} value_t;

module test;
  value_t value;

  initial begin
    if ($bits(value) != 8)
      $fatal(1, "soft packed union width is %0d", $bits(value));

    value = 8'ha5;
    if (value.low_nibble !== 4'h5 || value.nested.six !== 6'h25)
      $fatal(1, "soft members are not right-justified: %h", value);

    value.low_nibble = 4'h3;
    if (value !== 8'ha3)
      $fatal(1, "narrow write changed bits above member: %h", value);

    value.nested.pair = 2'b10;
    if (value !== 8'ha2 || value.nested.six !== 6'h22)
      $fatal(1, "nested narrow write changed unrelated bits: %h", value);

    $display("SOFT width=%0d value=%h nested=%h",
             $bits(value), value, value.nested.six);
    $display("PASSED");
  end
endmodule
