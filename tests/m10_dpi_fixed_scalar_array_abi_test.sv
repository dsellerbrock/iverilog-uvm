// IEEE 1800-2017 Annex H direct C ABI for fixed unpacked arrays.
// A true scalar bit/logic element is one svBit/svLogic byte. An explicitly
// packed [0:0] element has the same SV width but uses the canonical
// svBitVecVal/svLogicVecVal representation. Input, output, and inout arrays
// must retain that distinction, including X/Z copyback for four-state data.
module m10_dpi_fixed_scalar_array_abi_test;
  import "DPI-C" context function void c_mutate_fixed_scalar_arrays(
      input  bit in_bits[4],
      input  logic in_logic[4],
      inout  bit io_bits[4],
      inout  logic io_logic[4],
      output bit out_bits[4],
      output logic out_logic[4],
      inout  bit [0:0] packed_bits[4],
      inout  logic [0:0] packed_logic[4],
      output int status);

  bit in_bits[4];
  logic in_logic[4];
  bit io_bits[4];
  logic io_logic[4];
  bit out_bits[4];
  logic out_logic[4];
  bit [0:0] packed_bits[4];
  logic [0:0] packed_logic[4];
  bit expected_io_bits[4];
  logic expected_io_logic[4];
  bit expected_out_bits[4];
  logic expected_out_logic[4];
  bit expected_packed_bits[4];
  logic expected_packed_logic[4];
  int status;
  int errors = 0;

  initial begin
    in_bits = '{1'b0, 1'b1, 1'b1, 1'b0};
    in_logic = '{1'b0, 1'b1, 1'bz, 1'bx};
    io_bits = '{1'b1, 1'b0, 1'b1, 1'b0};
    io_logic = '{1'bx, 1'bz, 1'b1, 1'b0};
    packed_bits = '{1'b0, 1'b1, 1'b0, 1'b1};
    packed_logic = '{1'b0, 1'b1, 1'bz, 1'bx};
    out_bits = '{default:1'b1};
    out_logic = '{default:1'bx};
    status = -1;

    c_mutate_fixed_scalar_arrays(in_bits, in_logic, io_bits, io_logic,
                                 out_bits, out_logic,
                                 packed_bits, packed_logic, status);

    if (status != 0) begin
      $display("FAIL fixed scalar ABI C status=0x%0h", status);
      errors++;
    end
    expected_io_bits = '{1'b0, 1'b1, 1'b0, 1'b1};
    expected_io_logic = '{1'b1, 1'bx, 1'bz, 1'b0};
    expected_out_bits = '{1'b1, 1'b1, 1'b0, 1'b0};
    expected_out_logic = '{1'bz, 1'bx, 1'b0, 1'b1};
    expected_packed_bits = '{1'b1, 1'b1, 1'b0, 1'b0};
    expected_packed_logic = '{1'bx, 1'bz, 1'b1, 1'b0};
    for (int idx = 0; idx < 4; idx++) begin
      if (io_bits[idx] !== expected_io_bits[idx]) begin
        $display("FAIL fixed scalar bit inout idx=%0d value=%b expected=%b",
                 idx, io_bits[idx], expected_io_bits[idx]);
        errors++;
      end
      if (io_logic[idx] !== expected_io_logic[idx]) begin
        $display("FAIL fixed scalar logic inout idx=%0d value=%b expected=%b",
                 idx, io_logic[idx], expected_io_logic[idx]);
        errors++;
      end
      if (out_bits[idx] !== expected_out_bits[idx]) begin
        $display("FAIL fixed scalar bit output idx=%0d value=%b expected=%b",
                 idx, out_bits[idx], expected_out_bits[idx]);
        errors++;
      end
      if (out_logic[idx] !== expected_out_logic[idx]) begin
        $display("FAIL fixed scalar logic output idx=%0d value=%b expected=%b",
                 idx, out_logic[idx], expected_out_logic[idx]);
        errors++;
      end
      if (packed_bits[idx][0] !== expected_packed_bits[idx]) begin
        $display("FAIL fixed packed [0:0] bit idx=%0d value=%b expected=%b",
                 idx, packed_bits[idx], expected_packed_bits[idx]);
        errors++;
      end
      if (packed_logic[idx][0] !== expected_packed_logic[idx]) begin
        $display("FAIL fixed packed [0:0] logic idx=%0d value=%b expected=%b",
                 idx, packed_logic[idx], expected_packed_logic[idx]);
        errors++;
      end
    end

    if (errors == 0)
      $display("PASS m10_dpi_fixed_scalar_array_abi_test");
    $finish;
  end
endmodule
