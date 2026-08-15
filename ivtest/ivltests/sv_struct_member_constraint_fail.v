// A solver constraint on an unpacked-struct member is legal IEEE syntax, but
// treating it as unrepresentable and then ignoring it silently weakens the
// solve. Keep this shape compile-time-loud until member solver variables and
// write-back are implemented together.
typedef struct {
  rand bit [7:0] value;
} constrained_member_record_t;

class constrained_member_item;
  rand constrained_member_record_t record;
  constraint exact_value { record.value == 8'd90; }
endclass

module test;
  constrained_member_item item;
endmodule
