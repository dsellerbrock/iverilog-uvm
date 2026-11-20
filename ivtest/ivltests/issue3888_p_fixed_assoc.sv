class issue3888_payload;
  int tag;

  function new(int tag);
    this.tag = tag;
  endfunction
endclass

typedef bit signed [7:0] issue3888_map_t[int];
typedef int issue3888_queue_t[$];
typedef enum {IDLE = 1, BUSY = 2} issue3888_state_t;
typedef struct packed {
  logic [3:0] data;
  bit valid;
} issue3888_packed_t;

module issue3888_p_fixed_assoc;
  byte signed_maps[4:2][int];
  byte unsigned unsigned_maps[4:2][int unsigned];
  string strings[1:0][string];
  issue3888_payload objects[2:1][int];
  issue3888_payload payload, nil;
  issue3888_map_t nested[2:1][int];
  logic [3:0] four_state[1:0][int];
  issue3888_queue_t queues[2:1][int], queue_value;
  issue3888_state_t states[2:1][int];
  issue3888_packed_t packed_values[2:1][int];
  int slot;

  initial begin
    signed_maps[4][3] = 8'hff;
    signed_maps[4][-7] = 8'h80;
    signed_maps[3] = '{default:-23};
    unsigned_maps[4][32'hffff_ffff] = 8'hff;
    unsigned_maps[4][3] = 8'h80;
    strings[1] = '{"q\"\\":"a\n\"\\", default:"missing"};
    payload = new(17);
    objects[2][9] = nil;
    objects[2][-5] = payload;
    nested[2][-2] = '{3:8'hff, -6:8'hfe};
    four_state[1][0] = 4'b1xz0;
    queue_value = '{-3, -4};
    queues[2][-1] = queue_value;
    states[2][3] = BUSY;
    packed_values[2][3] = '{4'b10xz, 1'b1};

    $display("signed: %p", signed_maps);
    $display("constant: %p", signed_maps[4]);
    slot = 4;
    $display("variable: %p", signed_maps[slot]);
    slot = 2;
    $display("empty: %p", signed_maps[slot]);
    $display("unsigned: %p", unsigned_maps);
    $display("strings: %p", strings);
    $display("objects: %p", objects);
    $display("nested: %p", nested);
    $display("four state: %p", four_state);
    $display("queues: %p", queues);
    slot = 2;
    $display("enums: %p selected: %p", states, states[slot]);
    $display("packed: %p", packed_values);

    if (signed_maps[4].size() != 2 || signed_maps[3].size() != 0 ||
        signed_maps[2].size() != 0 || signed_maps[4][-7] !== 8'h80 ||
        signed_maps[3][99] != -23 ||
        strings[1].size() != 1 || strings[1]["q\"\\"] != "a\n\"\\" ||
        strings[1].exists("absent") || strings[1]["absent"] != "missing" ||
        objects[2].size() != 2 || objects[2][-5] != payload ||
        objects[2][9] != null)
      $fatal(1, "Formatting changed the associative array contents");
  end
endmodule
