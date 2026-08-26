// IEEE 1800-2017 13.5.2 plus Annex H: fixed-array argument copy-in/out maps
// declared left to declared left in every unpacked dimension, even when the
// caller actual and formal have opposite directions and different bounds.
// Once copied into the formal, C sees the formal's numeric-low-first,
// rightmost-dimension-fastest canonical buffer.
module m10_dpi_fixed_multidim_direction_abi_test;
  import "DPI-C" context function void c_mutate_fixed_multidim_direction(
      inout int values[5:4][-1:1], output int status);

  // Both actual dimensions run opposite to the corresponding formal:
  // actual [10:11] -> formal [5:4], actual [7:5] -> formal [-1:1].
  int actual[10:11][7:5];
  int status;
  int errors = 0;

  initial begin
    for (int i = 10; i <= 11; i++) begin
      for (int j = 5; j <= 7; j++)
        actual[i][j] = i * 100 + j;
    end
    status = -1;

    c_mutate_fixed_multidim_direction(actual, status);

    if (status != 0) begin
      $display("FAIL multidim direction ABI C status=0x%0h", status);
      errors++;
    end
    for (int i = 10; i <= 11; i++) begin
      for (int j = 5; j <= 7; j++) begin
        int canonical_slot;
        int expected;
        // actual outer 10/11 maps to formal 5/4; actual inner 7/6/5
        // maps to formal -1/0/1. Convert that formal index to its C slot.
        canonical_slot = (11 - i) * 3 + (7 - j);
        expected = 32'h0000_5000 + canonical_slot;
        if (actual[i][j] !== expected) begin
          $display("FAIL multidim direction actual[%0d][%0d]=%0d expected=%0d slot=%0d",
                   i, j, actual[i][j], expected, canonical_slot);
          errors++;
        end
      end
    end

    if (errors == 0)
      $display("PASS m10_dpi_fixed_multidim_direction_abi_test");
    $finish;
  end
endmodule
