// The supported unpacked-struct constraint leaf is deliberately one-level
// and scalar. Keep deeper aggregate traversal and an indexed unpacked member
// compile-time-loud instead of dropping either constraint.
typedef struct {
  rand bit [7:0] scalar;
} constrained_inner_t;

typedef struct {
  rand constrained_inner_t nested;
  rand bit [7:0] lanes[2];
  rand bit [64:0] wide;
} constrained_outer_t;

typedef struct {
  rand bit [7:0] value;
} indexed_outer_record_t;

class constrained_member_item;
  rand constrained_outer_t record;
  rand indexed_outer_record_t records[2];
  rand bit [7:0] value;
  constraint nested_path { record.nested.scalar == 8'd90; }
  constraint indexed_path { record.lanes[0] == 8'd12; }
  constraint wide_path { record.wide == 65'd7; }
  constraint indexed_outer_path { records[0].value == 8'd23; }
endclass

module test;
  constrained_member_item item;
endmodule
