// IEEE 1800-2017 7.4.2, 7.10: a signal-backed fixed unpacked array whose
// element type is a queue gives every fixed word its OWN runtime container.
//
// This declaration used to be rejected outright ("sorry: array of queue type
// is not yet supported for signal-backed declarations"). The backend that
// allocates one container per fixed word now exists, so the shape is
// supported and this test pins its semantics rather than its refusal. The
// two words carry different depths so a single shared container would be
// visible immediately.
module sv_signal_fixed_array_container;

  int values[2][$];
  int fails = 0;

  initial begin
    values[0].push_back(1);
    values[0].push_back(2);
    values[1].push_back(9);

    if (values[0].size() != 2) begin
      fails += 1;
      $display("FAILED: values[0].size() got %0d want 2", values[0].size());
    end
    if (values[1].size() != 1) begin
      fails += 1;
      $display("FAILED: values[1].size() got %0d want 1", values[1].size());
    end

    if (values[0][0] != 1 || values[0][1] != 2) begin
      fails += 1;
      $display("FAILED: values[0] contents got %0d,%0d want 1,2",
               values[0][0], values[0][1]);
    end
    if (values[1][0] != 9) begin
      fails += 1;
      $display("FAILED: values[1][0] got %0d want 9", values[1][0]);
    end

    // Mutating one word must leave the other untouched.
    values[0].delete();
    if (values[0].size() != 0 || values[1].size() != 1) begin
      fails += 1;
      $display("FAILED: words are not independent containers (%0d, %0d)",
               values[0].size(), values[1].size());
    end

    if (fails == 0)
      $display("PASSED");
  end

endmodule
