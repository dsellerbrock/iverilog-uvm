// IEEE 1800-2017/2023 25.7 and 6.22.1(f): full import prototypes are
// declarations and must match even when never called. Exercise representation
// kind, name significance with unpacked dimensions, exact fixed bounds,
// packed shape, queue-vs-associative kind, and associative index type.
interface prototype_type_if;
  typedef struct packed {
    logic [3:0] upper;
    logic [3:0] lower;
  } payload_t;

  task aggregate(input payload_t value); endtask
  task named_array(input logic [7:0] payload [0:1]); endtask
  task fixed_bounds(input logic [7:0] payload [0:1]); endtask
  task packed_shape(input logic [1:0][3:0] payload); endtask
  task queue_kind(input int payload[$]); endtask
  task assoc_index(input int payload[string]); endtask

  modport restricted(
      import task aggregate(input logic [7:0] value),
      import task named_array(input logic [7:0] wrong_name [0:1]),
      import task fixed_bounds(input logic [7:0] payload [1:0]),
      import task packed_shape(input logic [7:0] payload),
      import task queue_kind(input int payload[string]),
      import task assoc_index(input int payload[int])
  );
endinterface

module sv_vif_modport_prototype_type_mismatch_fail;
  prototype_type_if bus();
endmodule
