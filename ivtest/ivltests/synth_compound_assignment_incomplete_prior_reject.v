`begin_keywords "1800-2012"

module main (
  input logic select,
  input logic [7:0] data,
  output logic [7:0] result
);
  always_comb begin
    if (select)
      result = 8'h10;
    result |= data;
  end
endmodule

`end_keywords
