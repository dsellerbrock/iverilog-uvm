module test;
  typedef union tagged packed {
    bit [1:0] shortval;
    bit [7:0] longval;
    bit [3:0] midval;
  } value_t;
  typedef union tagged packed {
    bit [11:0] wide;
    value_t nested;
  } outer_t;
  value_t value;
  outer_t outer;
  initial begin
    if ($bits(value_t) != 10 || $bits(outer_t) != 13)
      $fatal(1, "wrong union width");
    value = tagged longval 8'ha5;
    if (value[9:8] !== 2'd1 || value[7:0] !== 8'ha5 || value.longval !== 8'ha5)
      $fatal(1, "long member: %b", value);
    value = tagged midval 4'hd;
    if (value[9:8] !== 2'd2 || value[3:0] !== 4'hd || value.midval !== 4'hd)
      $fatal(1, "middle member: %b", value);
    value = tagged shortval 2'b11;
    if (value[9:8] !== 2'd0 || value[1:0] !== 2'b11 || value.shortval !== 2'b11)
      $fatal(1, "short member: %b", value);
    outer = tagged nested value;
    if (outer[12] !== 1'b1 || outer[9:0] !== value)
      $fatal(1, "nested member: %b", outer);
    $display("PASS");
  end
endmodule
