// Fixed unpacked arrays whose packed elements exceed 255 bits. The direct
// DPI buffer must preserve the complete element width: eight svBitVecVal
// words for bit[255:0] and twelve svLogicVecVal entries for logic[383:0].
// This catches descriptor-width truncation as well as high-word copyback.
module m10_dpi_fixed_wide_element_abi_test;
  import "DPI-C" context function void c_mutate_fixed_wide_elements(
      inout bit [255:0] bit_data[2],
      inout logic [383:0] logic_data[2],
      output int status);

  bit [255:0] bit_data[2];
  logic [383:0] logic_data[2];
  logic [383:0] expected_logic[2];
  int status;
  int errors = 0;

  initial begin
    for (int elem = 0; elem < 2; elem++) begin
      for (int word = 0; word < 8; word++) begin
        bit_data[elem][word * 32 +: 32] =
            32'h1000_0000 + elem * 32'h0001_0000 + word;
      end
    end

    logic_data[0] = '0;
    logic_data[0][0] = 1'b1;
    logic_data[0][127] = 1'bx;
    logic_data[0][255] = 1'bz;
    logic_data[0][383] = 1'b1;
    logic_data[1] = '0;
    logic_data[1][31] = 1'bz;
    logic_data[1][192] = 1'bx;
    logic_data[1][300] = 1'b1;
    status = -1;

    c_mutate_fixed_wide_elements(bit_data, logic_data, status);

    if (status != 0) begin
      $display("FAIL fixed wide-element ABI C status=0x%0h", status);
      errors++;
    end
    for (int elem = 0; elem < 2; elem++) begin
      for (int word = 0; word < 8; word++) begin
        bit [31:0] expected;
        expected = 32'ha000_0000 + elem * 32'h0001_0000 + word;
        if (bit_data[elem][word * 32 +: 32] !== expected) begin
          $display("FAIL fixed bit[255:0] elem=%0d word=%0d got=%h expected=%h",
                   elem, word, bit_data[elem][word * 32 +: 32], expected);
          errors++;
        end
      end
    end

    expected_logic[0] = '0;
    expected_logic[0][2] = 1'bx;
    expected_logic[0][191] = 1'bz;
    expected_logic[0][382] = 1'b1;
    expected_logic[1] = '0;
    expected_logic[1][0] = 1'bz;
    expected_logic[1][129] = 1'bx;
    expected_logic[1][383] = 1'b1;
    for (int elem = 0; elem < 2; elem++) begin
      if (logic_data[elem] !== expected_logic[elem]) begin
        $display("FAIL fixed logic[383:0] elem=%0d got=%h expected=%h",
                 elem, logic_data[elem], expected_logic[elem]);
        errors++;
      end
    end

    if (errors == 0)
      $display("PASS m10_dpi_fixed_wide_element_abi_test");
    $finish;
  end
endmodule
