// IEEE 1800-2017 13.4.2, 18.4, and 18.5.10: parentheses may be omitted
// from a no-argument method call, including a dynamic array's size method,
// and that size may participate in solve-before ordering.
module main;
  // This is the Caliptra dma_transfer_randomizer constraint shape.
  class caliptra_size_item;
    rand int unsigned xfer_size;
    rand int unsigned payload_data[];
    constraint payload_data_size_c {
      if (xfer_size > 4)
        payload_data.size == 1;
      else
        payload_data.size == xfer_size;
      solve xfer_size before payload_data.size;
    }
  endclass

  // Put the size in the earlier ordering rank too, so the runtime must
  // recognize an s: token as an ordering variable and pin its staged model.
  class size_first_item;
    rand bit choose_one;
    rand byte unsigned values[];
    constraint possible_c {
      values.size == 1 || values.size == 2;
      if (choose_one) values.size == 1;
    }
    constraint order_c { solve values.size before choose_one; }
  endclass

  int errors = 0;

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      errors++;
    end
  endtask

  initial begin
    automatic caliptra_size_item caliptra = new;
    automatic size_first_item size_first = new;
    automatic int choose_one_count = 0;
    automatic int i;
    automatic int ok;

    ok = caliptra.randomize() with { xfer_size == 3; };
    check("Caliptra else branch", ok && caliptra.xfer_size == 3
          && caliptra.payload_data.size() == 3);

    ok = caliptra.randomize() with { xfer_size == 6; };
    check("Caliptra if branch", ok && caliptra.xfer_size == 6
          && caliptra.payload_data.size() == 1);

    size_first.srandom(32'h51ae_1800);
    for (i = 0; i < 128; i++) begin
      ok = size_first.randomize();
      check("size-first randomize", ok);
      check("size-first domain", size_first.values.size() == 1
            || size_first.values.size() == 2);
      check("size-first implication", !size_first.choose_one
            || size_first.values.size() == 1);
      if (size_first.choose_one) choose_one_count++;
    end
    // Solving size first makes sizes 1 and 2 roughly equiprobable, then
    // choose_one is free only for size 1: expect about one quarter true.
    // The bounds are intentionally loose but reject the old unordered
    // behavior, which makes choose_one true about half the time.
    check("size-first distribution", choose_one_count >= 8
          && choose_one_count <= 48);

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d errors (choose_one=%0d)",
               errors, choose_one_count);
  end
endmodule
