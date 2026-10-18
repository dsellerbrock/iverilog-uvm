// IEEE 1800-2017/2023 18.4: without a size constraint, a rand dynamic array
// keeps its existing size and all elements, including nested members of a
// rand unpacked struct, participate in randomization.
typedef struct {
  rand bit [31:0] values[][];
} nested_dynamic_member_record_t;

class nested_dynamic_member_item;
  rand nested_dynamic_member_record_t record;
  rand bit [31:0] gate;
  bit force_values;
  bit force_resize;
  bit force_conflict;
  constraint nested_values_c {
    if (force_resize) {
      record.values.size() == 1;
      foreach (record.values[i]) record.values[i].size() == 2;
      record.values[0][1] == 32'h2468_ace0;
    }
    if (force_values) {
      record.values[0][0] == 32'h1357_2468;
      record.values[1][0] == 32'h89ab_cdef;
    }
    if (force_conflict) {
      gate == 32'h0000_0000;
      gate == 32'h0000_0001;
    }
  }
endclass

module test;
  nested_dynamic_member_item item;
  bit [31:0] row0[], row1[];
  bit [31:0] saved0, saved1;
  initial begin
    item = new;
    item.srandom(32'h4190_1804);
    item.record.values = new[2];
    item.record.values[0] = new[1];
    item.record.values[1] = new[1];
    item.record.values[0][0] = 32'h1234_5678;
    item.record.values[1][0] = 32'h9abc_def0;
    item.record.values[0][0].rand_mode(0);
    if (item.record.values[0][0].rand_mode() !== 0)
      $fatal(1, "nested array rand_mode did not disable its element");

    if (!item.randomize()) $fatal(1, "nested struct dynamic-array randomize failed");
    row0 = item.record.values[0];
    row1 = item.record.values[1];
    if (item.record.values.size() != 2 || row0.size() != 1 || row1.size() != 1
        || row0[0] != 32'h1234_5678 || row1[0] == 32'h9abc_def0)
      $fatal(1, "nested struct dynamic-array elements or modes were not randomized");
    saved0 = row0[0];
    saved1 = row1[0];

    item.record.values[0][0].rand_mode(1);
    if (item.record.values[0][0].rand_mode() !== 1)
      $fatal(1, "nested array rand_mode did not re-enable its element");
    item.force_values = 1;
    if (!item.randomize()) $fatal(1, "nested struct element constraints failed");
    row0 = item.record.values[0];
    row1 = item.record.values[1];
    if (item.record.values.size() != 2 || row0.size() != 1 || row1.size() != 1
        || row0[0] != 32'h1357_2468 || row1[0] != 32'h89ab_cdef)
      $fatal(1, "nested struct array elements did not honor class constraints");
    saved0 = row0[0];
    saved1 = row1[0];

    item.force_values = 0;
    item.force_resize = 1;
    if (!item.randomize()) $fatal(1, "nested struct dynamic-array resize failed");
    row0 = item.record.values[0];
    if (item.record.values.size() != 1 || row0.size() != 2
        || row0[1] != 32'h2468_ace0)
      $fatal(1, "nested struct array sizes or new constrained leaf were wrong");
    saved0 = row0[0];
    saved1 = row0[1];

    item.force_conflict = 1;
    if (item.randomize()) $fatal(1, "contradictory nested member constraints solved");
    row0 = item.record.values[0];
    if (item.record.values.size() != 1 || row0.size() != 2
        || row0[0] != saved0 || row0[1] != saved1)
      $fatal(1, "failed randomize changed nested struct dynamic-array state");

    $display("PASSED");
  end
endmodule
