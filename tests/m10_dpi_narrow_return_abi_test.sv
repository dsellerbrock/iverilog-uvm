// IEEE 1800 Annex H scalar and integer-atom return ABI.
//
// These signatures mirror OpenTitan's commercial-simulator DPI boundary:
// spidpi/uartdpi return plain C char, usbdpi returns uint8_t, and several
// models return svBit. The plain-char round trip is also run with a companion
// built under -funsigned-char. A scalar logic result additionally proves that
// svLogic X/Z encoding is decoded instead of being truncated as a 2-state int.
module m10_dpi_narrow_return_abi_test;
  typedef enum byte {
    ENUM_BYTE_VALUE = -127
  } byte_enum_t;
  typedef enum int unsigned {
    ENUM_UINT_VALUE = 32'hfeed_beef
  } uint_enum_t;

  import "DPI-C" function byte c_dpi_return_sbyte(
      input chandle ctx, input logic [1:0] d2p);
  import "DPI-C" function byte unsigned c_dpi_return_ubyte(
      input chandle ctx, input bit [10:0] d2p);
  import "DPI-C" function byte c_dpi_plain_char_roundtrip(
      input byte value, output byte out_value);
  import "DPI-C" function shortint c_dpi_return_sshort(input int selector);
  import "DPI-C" function shortint unsigned c_dpi_return_ushort(
      input int selector);
  import "DPI-C" function bit c_dpi_return_bit(input int selector);
  import "DPI-C" function logic c_dpi_return_logic(input int selector);
  import "DPI-C" function byte_enum_t c_dpi_return_byte_enum();
  import "DPI-C" function uint_enum_t c_dpi_return_uint_enum();

  chandle ctx;
  byte signed_result;
  byte unsigned unsigned_result;
  byte plain_char_result;
  byte plain_char_output;
  shortint signed_short_result;
  shortint unsigned unsigned_short_result;
  bit bit_result;
  logic logic_x;
  logic logic_z;
  byte_enum_t byte_enum_result;
  uint_enum_t uint_enum_result;
  int errors = 0;

  initial begin
    signed_result = c_dpi_return_sbyte(ctx, 2'b1x);
    unsigned_result = c_dpi_return_ubyte(ctx, 11'h5a5);
    plain_char_result = c_dpi_plain_char_roundtrip(8'h80,
                                                   plain_char_output);
    signed_short_result = c_dpi_return_sshort(16'h1234);
    unsigned_short_result = c_dpi_return_ushort(16'h5678);
    bit_result = c_dpi_return_bit(7);
    logic_x = c_dpi_return_logic(0);
    logic_z = c_dpi_return_logic(1);
    byte_enum_result = c_dpi_return_byte_enum();
    uint_enum_result = c_dpi_return_uint_enum();

    if (signed_result !== 8'h80) begin
      $display("FAIL signed byte return: got %02h", signed_result);
      errors++;
    end
    if (unsigned_result !== 8'hfe) begin
      $display("FAIL unsigned byte return: got %02h", unsigned_result);
      errors++;
    end
    if (plain_char_result !== 8'h83 || plain_char_output !== 8'hd5) begin
      $display("FAIL plain char ABI result=%02h output=%02h",
               plain_char_result, plain_char_output);
      errors++;
    end
    if (signed_short_result !== 16'h8001) begin
      $display("FAIL signed shortint return: got %04h", signed_short_result);
      errors++;
    end
    if (unsigned_short_result !== 16'hfffe) begin
      $display("FAIL unsigned shortint return: got %04h",
               unsigned_short_result);
      errors++;
    end
    if (bit_result !== 1'b1) begin
      $display("FAIL bit return: got %b", bit_result);
      errors++;
    end
    if (logic_x !== 1'bx) begin
      $display("FAIL logic X return: got %b", logic_x);
      errors++;
    end
    if (logic_z !== 1'bz) begin
      $display("FAIL logic Z return: got %b", logic_z);
      errors++;
    end
    if (byte_enum_result !== ENUM_BYTE_VALUE) begin
      $display("FAIL byte enum return: got %02h", byte_enum_result);
      errors++;
    end
    if (uint_enum_result !== ENUM_UINT_VALUE) begin
      $display("FAIL uint enum return: got %08h", uint_enum_result);
      errors++;
    end

    if (errors == 0)
      $display("PASS m10_dpi_narrow_return_abi_test");
    $finish;
  end
endmodule
