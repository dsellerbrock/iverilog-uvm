// IEEE 1800-2017 18.3, 18.4, 18.5.10, and 18.8: a scalar member of a
// rand unpacked-struct property is an independently controlled constraint
// variable. State members are read at solve time, enums stay in their
// declared domain, solve-before keeps the member identity, and randc/value
// updates roll back together after an unsatisfiable call.
typedef enum bit [3:0] {
  KIND_A = 4'd1,
  KIND_B = 4'd4,
  KIND_C = 4'd9
} member_kind_e;

typedef struct {
  rand bit [7:0] value;
  rand member_kind_e kind;
  randc bit [2:0] cycle;
  bit [7:0] state;
} constrained_member_record_t;

class constrained_member_item;
  rand constrained_member_record_t record;

  constraint member_values {
    record.value == record.state;
    record.kind inside {[4'd0:4'd15]};
    record.cycle inside {3'd1, 3'd3, 3'd6};
    solve record.kind before record.value;
  }
endclass

module test;
  initial begin
    constrained_member_item item;
    bit seen[8];
    bit saved_mode;
    bit [7:0] saved_value;
    member_kind_e saved_kind;
    bit [2:0] saved_cycle;

    item = new;
    item.srandom(32'h1804_0510);
    item.record.state = 8'd90;

    if (item.randomize() !== 1)
      $fatal(1, "initial unpacked-struct member solve failed");
    if (item.record.value !== 8'd90)
      $fatal(1, "scalar member constraint was not written back");
    if (!(item.record.kind inside {KIND_A, KIND_B, KIND_C}))
      $fatal(1, "enum member escaped its sparse declared domain");
    if (!(item.record.cycle inside {3'd1, 3'd3, 3'd6}))
      $fatal(1, "randc member escaped its feasible domain");
    seen[item.record.cycle] = 1'b1;

    saved_mode = item.record.value.rand_mode();
    if (saved_mode !== 1'b1)
      $fatal(1, "rand_mode query did not identify an active struct member");
    item.record.value.rand_mode(0);
    if (item.record.value.rand_mode() !== 1'b0)
      $fatal(1, "rand_mode setter did not freeze the struct member");
    item.record.value = 8'd37;
    item.record.state = 8'd37;
    if (item.randomize() !== 1 || item.record.value !== 8'd37)
      $fatal(1, "frozen satisfying member was not treated as state");
    if (seen[item.record.cycle])
      $fatal(1, "randc member repeated within its feasible cycle");
    seen[item.record.cycle] = 1'b1;

    saved_value = item.record.value;
    saved_kind = item.record.kind;
    saved_cycle = item.record.cycle;
    item.record.state = 8'd38;
    if (item.randomize() !== 0)
      $fatal(1, "frozen contradictory member unexpectedly solved");
    if (item.record.value !== saved_value
        || item.record.kind !== saved_kind
        || item.record.cycle !== saved_cycle)
      $fatal(1, "failed member solve did not roll back atomically");

    item.record.value.rand_mode(saved_mode);
    if (item.record.value.rand_mode() !== 1'b1)
      $fatal(1, "rand_mode restore did not reactivate the struct member");
    item.record.state = 8'd55;
    if (item.randomize() !== 1 || item.record.value !== 8'd55)
      $fatal(1, "reactivated member did not receive the solved model");
    if (seen[item.record.cycle])
      $fatal(1, "failed solve consumed randc member history");
    seen[item.record.cycle] = 1'b1;

    foreach (seen[value])
      if ((value == 1 || value == 3 || value == 6) && !seen[value])
        $fatal(1, "randc member missed a feasible-cycle value");

    $display("PASSED");
  end
endmodule
