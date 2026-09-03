// IEEE 1800-2017 7.4.2, 7.10, 8.9: a STATIC class property that is a fixed
// unpacked array of queues gives each fixed word its own runtime container,
// shared by every reference to the class.
//
// This declaration used to be rejected outright. The signal-backed storage it
// uses now allocates one container per fixed word, so the shape is supported
// and this test pins its semantics.
//
// Deliberately scoped: reading a single ELEMENT through an indexed static
// property (`holder::values[0][1]`) is still unsupported and still reports
// "sorry: this indexed static-property read form is not yet supported". That
// residual gap is pinned by the companion negative test
// sv_class_static_fixed_array_container_element_read_fail, so this test stays
// on the surface that works: push_back, size(), delete() and foreach.
class static_fixed_array_container_holder;
  static int values[2][$];
endclass

module sv_class_static_fixed_array_container_property;

  int fails = 0;
  int word_count = 0;

  initial begin
    static_fixed_array_container_holder::values[0].push_back(1);
    static_fixed_array_container_holder::values[0].push_back(2);
    static_fixed_array_container_holder::values[1].push_back(9);

    if (static_fixed_array_container_holder::values[0].size() != 2) begin
      fails += 1;
      $display("FAILED: values[0].size() got %0d want 2",
               static_fixed_array_container_holder::values[0].size());
    end
    if (static_fixed_array_container_holder::values[1].size() != 1) begin
      fails += 1;
      $display("FAILED: values[1].size() got %0d want 1",
               static_fixed_array_container_holder::values[1].size());
    end

    foreach (static_fixed_array_container_holder::values[i])
      word_count += 1;
    if (word_count != 2) begin
      fails += 1;
      $display("FAILED: foreach saw %0d words want 2", word_count);
    end

    // The words must be independent containers, not one shared queue.
    static_fixed_array_container_holder::values[0].delete();
    if (static_fixed_array_container_holder::values[0].size() != 0
        || static_fixed_array_container_holder::values[1].size() != 1) begin
      fails += 1;
      $display("FAILED: static words are not independent (%0d, %0d)",
               static_fixed_array_container_holder::values[0].size(),
               static_fixed_array_container_holder::values[1].size());
    end

    if (fails == 0)
      $display("PASSED");
  end

endmodule
