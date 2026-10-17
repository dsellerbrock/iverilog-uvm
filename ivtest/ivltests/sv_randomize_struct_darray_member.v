// IEEE 1800-2017/2023 18.4: random members of a rand unpacked struct are
// solved with the class, and a rand array's elements remain random when its
// unconstrained size is preserved.
typedef enum bit [1:0] { tag_idle, tag_data, tag_last } tag_t;
typedef struct { rand bit [3:0] values[]; rand tag_t tags[]; } nested_values_t;

class nested_values_item;
  rand nested_values_t payload;
  constraint payload_values {
    payload.values[0] == 4'h3;
    payload.values[1] == 4'h9;
    payload.tags[0] == tag_idle;
    payload.tags[1] == tag_data;
  }
endclass

typedef struct { rand bit [7:0] values[]; } mode_values_t;
class mode_values_item;
  rand mode_values_t payload;
  constraint changed_value { payload.values[0] != 8'h5a; }
endclass

module test;
  nested_values_item item;
  mode_values_item mode_item;
  initial begin
    item = new;
    item.payload.values = new[2];
    item.payload.tags = new[2];
    item.payload.values[0] = 0;
    item.payload.values[1] = 0;
    item.payload.tags[0] = tag_last;
    item.payload.tags[1] = tag_last;
    if (!item.randomize()) $fatal(1, "struct array member randomize failed");
    if (item.payload.values.size() != 2 || item.payload.values[0] != 4'h3
        || item.payload.values[1] != 4'h9 || item.payload.tags.size() != 2
        || item.payload.tags[0] != tag_idle || item.payload.tags[1] != tag_data)
      $fatal(1, "struct array member values were not constrained");
    // IEEE 1800-2017/2023 18.6.3: failed randomization retains old values.
    if (item.randomize() with { payload.values[0] == 4'h4; })
      $fatal(1, "contradictory struct array member constraint solved");
    if (item.payload.values.size() != 2 || item.payload.values[0] != 4'h3
        || item.payload.values[1] != 4'h9 || item.payload.tags.size() != 2
        || item.payload.tags[0] != tag_idle || item.payload.tags[1] != tag_data)
      $fatal(1, "failed randomize changed struct array member state");
    mode_item = new;
    mode_item.payload.values = new[1];
    mode_item.payload.values[0] = 8'h5a;
    mode_item.payload.values.rand_mode(0);
    if (mode_item.randomize() || mode_item.payload.values.size() != 1
        || mode_item.payload.values[0] != 8'h5a)
      $fatal(1, "disabled struct array member did not retain its value");
    $display("PASSED");
  end
endmodule
