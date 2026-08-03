package packed_array_pattern_port_context_pkg;
  typedef struct packed {
    logic [7:0] base;
    logic [7:0] limit;
  } range_t;
  parameter range_t RANGE_DEFAULT = '{base: 8'h12, limit: 8'h34};
endpackage

module packed_array_pattern_port_context_child(
  input packed_array_pattern_port_context_pkg::range_t [0:0] ranges_i,
  output logic [15:0] value_o
);
  assign value_o = ranges_i[0];
endmodule

module packed_array_pattern_port_context_test;
  import packed_array_pattern_port_context_pkg::*;
  wire [15:0] value;
  packed_array_pattern_port_context_child child (
    .ranges_i('{RANGE_DEFAULT}),
    .value_o(value)
  );
  initial begin
    #1;
    if (value !== 16'h1234)
      $fatal(1, "packed-array assignment-pattern port context failed");
    $display("PASS: packed-array assignment-pattern port context");
  end
endmodule
