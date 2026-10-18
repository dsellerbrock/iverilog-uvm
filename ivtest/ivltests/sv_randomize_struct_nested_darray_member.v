// IEEE 1800-2017/2023 18.4: without a size constraint, a rand dynamic array
// keeps its existing size and all of its nested elements are randomized.
typedef struct {
  rand bit [31:0] values[][];
} nested_dynamic_member_record_t;

class nested_dynamic_member_item;
  rand nested_dynamic_member_record_t record;
  rand bit [31:0] gate;
  bit force_conflict;
  constraint conflict_c {
    if (force_conflict) {
      gate == 32'h0000_0000;
      gate == 32'h0000_0001;
    }
  }
endclass

module test;
  nested_dynamic_member_item item;
  bit [31:0] row0[], row1[];
  bit [31:0] original0, original1, saved0, saved1;
  initial begin
    item = new;
    item.srandom(32'h4190_1804);
    item.record.values = new[2];
    item.record.values[0] = new[1];
    item.record.values[1] = new[1];
    item.record.values[0][0] = 32'h1234_5678;
    item.record.values[1][0] = 32'h9abc_def0;
    row0 = item.record.values[0];
    row1 = item.record.values[1];
    original0 = row0[0];
    original1 = row1[0];

    if (!item.randomize()) $fatal(1, "nested struct dynamic-array randomize failed");
    row0 = item.record.values[0];
    row1 = item.record.values[1];
    if (item.record.values.size() != 2 || row0.size() != 1 || row1.size() != 1
        || row0[0] == original0 || row1[0] == original1)
      $fatal(1, "nested struct dynamic-array elements were not randomized");
    saved0 = row0[0];
    saved1 = row1[0];

    item.force_conflict = 1;
    if (item.randomize()) $fatal(1, "contradictory nested member constraints solved");
    row0 = item.record.values[0];
    if (item.record.values.size() != 1 || row0.size() != 2
        || row0[0] != saved0 || row0[1] != saved1)
      $fatal(1, "failed randomize changed nested struct dynamic-array state");

    $display("PASSED");
  end
endmodule
