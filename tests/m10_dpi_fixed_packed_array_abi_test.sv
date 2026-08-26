// IEEE 1800-2017 Annex H direct C ABI for fixed unpacked arrays whose
// elements are packed vectors. Each element occupies an integral number of
// canonical 32-bit words: one word for bit[7:0], two for bit[39:0], and two
// svLogicVecVal entries for logic[39:0]. Inout changes, including X and Z,
// must copy back to the fixed SV arrays.
module m10_dpi_fixed_packed_array_abi_test;
  import "DPI-C" context function void c_mutate_fixed_packed_arrays(
      inout bit [7:0] bytes[3],
      inout bit [39:0] wide[2],
      inout logic [39:0] states[2],
      output int status);

  bit [7:0] bytes[3];
  bit [39:0] wide[2];
  logic [39:0] states[2];
  logic [39:0] expected_states[2];
  int status;
  int errors = 0;

  initial begin
    bytes[0] = 8'h12;
    bytes[1] = 8'ha5;
    bytes[2] = 8'h5a;
    wide[0] = 40'h12_3456_789a;
    wide[1] = 40'hab_cdef_0123;

    states[0] = 40'h12_3456_789a;
    states[0][3] = 1'bx;
    states[0][37] = 1'bz;
    states[1] = 40'hab_cdef_0123;
    states[1][0] = 1'bz;
    states[1][39] = 1'bx;

    status = -1;
    c_mutate_fixed_packed_arrays(bytes, wide, states, status);

    if (status != 0) begin
      $display("FAIL fixed packed ABI C status=0x%0h", status);
      errors++;
    end
    if (bytes[0] != 8'he1 || bytes[1] != 8'h3c || bytes[2] != 8'he2) begin
      $display("FAIL fixed byte ABI values=%h/%h/%h",
               bytes[0], bytes[1], bytes[2]);
      errors++;
    end
    if (wide[0] != 40'h55_89ab_cdef || wide[1] != 40'haa_0123_4567) begin
      $display("FAIL fixed wide ABI values=%h/%h", wide[0], wide[1]);
      errors++;
    end

    expected_states[0] = 40'h55_89ab_cdef;
    expected_states[0][1] = 1'bx;
    expected_states[0][34] = 1'bz;
    expected_states[1] = 40'haa_0123_4567;
    expected_states[1][5] = 1'bz;
    expected_states[1][38] = 1'bx;
    if (states[0] !== expected_states[0] ||
        states[1] !== expected_states[1]) begin
      $display("FAIL fixed logic ABI states=%h/%h expected=%h/%h",
               states[0], states[1], expected_states[0], expected_states[1]);
      errors++;
    end

    if (errors == 0)
      $display("PASS m10_dpi_fixed_packed_array_abi_test");
    $finish;
  end
endmodule
