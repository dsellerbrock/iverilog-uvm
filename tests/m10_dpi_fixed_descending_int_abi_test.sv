// IEEE 1800-2017 Annex H direct C ABI for a descending fixed unpacked
// array. The C buffer is normalized to low declared index first: C slot 0
// represents SV element [3], and C slot 7 represents SV element [10].
// Inout copyback must preserve that mapping in the reverse direction.
module m10_dpi_fixed_descending_int_abi_test;
  import "DPI-C" context function void c_mutate_descending_ints(
      inout int values[10:3], output int status);

  int values[10:3];
  int status;
  int errors = 0;

  initial begin
    foreach (values[i]) values[i] = i * 100 + 7;
    status = -1;

    c_mutate_descending_ints(values, status);

    if (status != 0) begin
      $display("FAIL descending fixed int ABI C status=0x%0h", status);
      errors++;
    end
    foreach (values[i]) begin
      int expected;
      expected = 32'h0001_0000 + i * 17;
      if (values[i] !== expected) begin
        $display("FAIL descending fixed int ABI values[%0d]=%0d expected=%0d",
                 i, values[i], expected);
        errors++;
      end
    end

    if (errors == 0)
      $display("PASS m10_dpi_fixed_descending_int_abi_test");
    $finish;
  end
endmodule
