// IEEE 1800-2017/2023 18.4: random members of a rand unpacked struct are
// solved with the class, and a rand array's elements remain random when its
// unconstrained size is preserved.
typedef struct { rand bit [3:0] values[]; } nested_values_t;

class nested_values_item;
  rand nested_values_t payload;
  constraint payload_values {
    payload.values[0] == 4'h3;
    payload.values[1] == 4'h9;
  }
endclass

module test;
  nested_values_item item;
  initial begin
    item = new;
    item.payload.values = new[2];
    item.payload.values[0] = 0;
    item.payload.values[1] = 0;
    if (!item.randomize()) $fatal(1, "struct array member randomize failed");
    if (item.payload.values.size() != 2 || item.payload.values[0] != 4'h3
        || item.payload.values[1] != 4'h9)
      $fatal(1, "struct array member values were not constrained");
    // IEEE 1800-2017/2023 18.6.3: failed randomization retains old values.
    if (item.randomize() with { payload.values[0] == 4'h4; })
      $fatal(1, "contradictory struct array member constraint solved");
    if (item.payload.values.size() != 2 || item.payload.values[0] != 4'h3
        || item.payload.values[1] != 4'h9)
      $fatal(1, "failed randomize changed struct array member state");
    $display("PASSED");
  end
endmodule
