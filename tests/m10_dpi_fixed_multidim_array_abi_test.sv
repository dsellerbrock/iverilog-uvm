// IEEE 1800-2017 Annex H direct C ABI for multidimensional fixed unpacked
// arrays. Every unpacked dimension is normalized to increasing declared
// index, with the rightmost dimension varying fastest (row-major). Declared
// ascending/descending directions therefore must not change the C layout.
// The five arguments span scalar bit/logic, a 32-bit atom, and packed
// bit/logic elements so every direct fixed-array representation is covered.
module m10_dpi_fixed_multidim_array_abi_test;
  import "DPI-C" context function void c_mutate_fixed_multidim_arrays(
      inout bit scalar_bits[2:0][4:5],
      inout logic scalar_logic[-1:1][3:2],
      inout int atoms[5:4][-2:0],
      inout bit [39:0] packed_bits[1:2][7:5],
      inout logic [39:0] packed_logic[4:2][-1:0],
      output int status);

  bit scalar_bits[2:0][4:5];
  logic scalar_logic[-1:1][3:2];
  int atoms[5:4][-2:0];
  bit [39:0] packed_bits[1:2][7:5];
  logic [39:0] packed_logic[4:2][-1:0];
  int status;
  int errors = 0;

  function automatic logic input_scalar_logic(input int slot);
    case (slot)
      0: input_scalar_logic = 1'b0;
      1: input_scalar_logic = 1'b1;
      2: input_scalar_logic = 1'bz;
      3: input_scalar_logic = 1'bx;
      4: input_scalar_logic = 1'b1;
      default: input_scalar_logic = 1'b0;
    endcase
  endfunction

  function automatic logic output_scalar_logic(input int slot);
    case (slot)
      0: output_scalar_logic = 1'bx;
      1: output_scalar_logic = 1'bz;
      2: output_scalar_logic = 1'b1;
      3: output_scalar_logic = 1'b0;
      4: output_scalar_logic = 1'bx;
      default: output_scalar_logic = 1'bz;
    endcase
  endfunction

  initial begin
    for (int i = 0; i <= 2; i++) begin
      for (int j = 4; j <= 5; j++) begin
        int slot;
        slot = i * 2 + (j - 4);
        scalar_bits[i][j] = slot[0];
      end
    end
    for (int i = -1; i <= 1; i++) begin
      for (int j = 2; j <= 3; j++) begin
        int slot;
        slot = (i + 1) * 2 + (j - 2);
        scalar_logic[i][j] = input_scalar_logic(slot);
      end
    end
    for (int i = 4; i <= 5; i++) begin
      for (int j = -2; j <= 0; j++) begin
        int slot;
        slot = (i - 4) * 3 + (j + 2);
        atoms[i][j] = 1000 + slot * 17;
      end
    end
    for (int i = 1; i <= 2; i++) begin
      for (int j = 5; j <= 7; j++) begin
        int slot;
        slot = (i - 1) * 3 + (j - 5);
        packed_bits[i][j][31:0] = 32'h1000_0000 + slot;
        packed_bits[i][j][39:32] = 8'h80 + slot;
      end
    end
    for (int i = 2; i <= 4; i++) begin
      for (int j = -1; j <= 0; j++) begin
        int slot;
        slot = (i - 2) * 2 + (j + 1);
        packed_logic[i][j][31:0] = 32'h2000_0000 + slot;
        packed_logic[i][j][39:32] = 8'h20 + slot;
        packed_logic[i][j][slot % 32] = 1'bx;
        packed_logic[i][j][32 + (slot % 8)] = 1'bz;
      end
    end
    status = -1;

    c_mutate_fixed_multidim_arrays(scalar_bits, scalar_logic, atoms,
                                   packed_bits, packed_logic, status);

    if (status != 0) begin
      $display("FAIL fixed multidim ABI C status=0x%0h", status);
      errors++;
    end
    for (int i = 0; i <= 2; i++) begin
      for (int j = 4; j <= 5; j++) begin
        int slot;
        slot = i * 2 + (j - 4);
        if (scalar_bits[i][j] !== ~slot[0]) begin
          $display("FAIL multidim scalar bit [%0d][%0d]=%b slot=%0d",
                   i, j, scalar_bits[i][j], slot);
          errors++;
        end
      end
    end
    for (int i = -1; i <= 1; i++) begin
      for (int j = 2; j <= 3; j++) begin
        int slot;
        slot = (i + 1) * 2 + (j - 2);
        if (scalar_logic[i][j] !== output_scalar_logic(slot)) begin
          $display("FAIL multidim scalar logic [%0d][%0d]=%b slot=%0d",
                   i, j, scalar_logic[i][j], slot);
          errors++;
        end
      end
    end
    for (int i = 4; i <= 5; i++) begin
      for (int j = -2; j <= 0; j++) begin
        int slot;
        int expected;
        slot = (i - 4) * 3 + (j + 2);
        expected = -2000 + slot * 31;
        if (atoms[i][j] !== expected) begin
          $display("FAIL multidim atom [%0d][%0d]=%0d expected=%0d",
                   i, j, atoms[i][j], expected);
          errors++;
        end
      end
    end
    for (int i = 1; i <= 2; i++) begin
      for (int j = 5; j <= 7; j++) begin
        int slot;
        slot = (i - 1) * 3 + (j - 5);
        if (packed_bits[i][j][31:0] !== 32'ha000_0000 + slot ||
            packed_bits[i][j][39:32] !== 8'h40 + slot) begin
          $display("FAIL multidim packed bit [%0d][%0d]=%h slot=%0d",
                   i, j, packed_bits[i][j], slot);
          errors++;
        end
      end
    end
    for (int i = 2; i <= 4; i++) begin
      for (int j = -1; j <= 0; j++) begin
        int slot;
        logic [39:0] expected;
        slot = (i - 2) * 2 + (j + 1);
        expected[31:0] = 32'hb000_0000 + slot;
        expected[39:32] = 8'h60 + slot;
        expected[(slot + 3) % 32] = 1'bx;
        expected[32 + ((slot + 2) % 8)] = 1'bz;
        if (packed_logic[i][j] !== expected) begin
          $display("FAIL multidim packed logic [%0d][%0d]=%h expected=%h",
                   i, j, packed_logic[i][j], expected);
          errors++;
        end
      end
    end

    if (errors == 0)
      $display("PASS m10_dpi_fixed_multidim_array_abi_test");
    $finish;
  end
endmodule
