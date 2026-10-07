// Indexed outer unpacked-struct constraint paths remain live at runtime.
typedef struct {
  rand bit [7:0] lanes[2];
} constrained_outer_t;

typedef struct {
  rand bit [7:0] value;
} indexed_outer_record_t;

class constrained_member_item;
  rand constrained_outer_t record;
  rand indexed_outer_record_t records[2];
  rand bit [7:0] value;
  constraint indexed_path { record.lanes[0] == 8'd12; }
  constraint indexed_outer_path { records[0].value == 8'd23; }
endclass

module test;
  constrained_member_item item;

  initial begin
    item = new;
    if (item.randomize() !== 1)
      $fatal(1, "indexed struct-member constraint solve failed");
    if (item.record.lanes[0] !== 8'd12 || item.records[0].value !== 8'd23)
      $fatal(1, "indexed struct-member constraint values were not written back");
    $display("PASSED");
  end
endmodule
