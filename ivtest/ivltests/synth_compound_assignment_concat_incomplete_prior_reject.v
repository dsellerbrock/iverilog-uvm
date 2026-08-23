`begin_keywords "1800-2012"

module main (
  input logic [7:0] data,
  output logic [7:0] result
);
  typedef struct packed {
    logic [3:0] high;
    logic [3:0] low;
  } pair_t;

  pair_t value;
  always_comb begin
    value.high = data[7:4];
    {value.high, value.low} += data;
    result = value;
  end
endmodule

`end_keywords
