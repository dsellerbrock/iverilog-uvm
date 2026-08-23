`begin_keywords "1800-2012"

class compound_holder;
  logic [7:0] value;
endclass

module dynamic_carrier (
  input logic [7:0] data
);
  logic [7:0] values[];

  always_comb
    values[0] += data;
endmodule

module queue_carrier (
  input logic [7:0] data
);
  logic [7:0] values[$];

  always_comb
    values[0] += data;
endmodule

module object_carrier (
  input logic [7:0] data
);
  compound_holder values[1];

  always_comb
    values[0].value += data;
endmodule

`end_keywords
