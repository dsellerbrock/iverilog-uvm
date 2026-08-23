`begin_keywords "1800-2012"

class synthesis_holder;
  logic [7:0] value;
  logic [7:0] fixed_values [0:1];
  logic [7:0] dynamic_values [];
  logic [7:0] queue_values [$];
endclass

module main (
  input logic [7:0] data
);
  synthesis_holder plain_object;
  synthesis_holder compound_object;

  // A class handle has one object nexus; it is not the packed carrier for a
  // nested property. Both paths must reject before making packed-width map
  // assumptions (the plain assignment previously aborted the compiler).
  always_comb
    plain_object.value = data;

  always_comb
    compound_object.value += data;

  // A property's element index belongs to the nested property carrier, not
  // the root class handle. Nonzero indices previously reached output-map
  // discovery first and were applied to the handle's sole object pin.
  always_comb
    plain_object.fixed_values[1] = data;

  always_comb
    plain_object.dynamic_values[1] = data;

  always_comb
    plain_object.queue_values[1] = data;

  always_comb
    compound_object.fixed_values[1] += data;

  always_comb
    compound_object.dynamic_values[1] += data;

  always_comb
    compound_object.queue_values[1] += data;
endmodule

`end_keywords
