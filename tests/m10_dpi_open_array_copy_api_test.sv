// IEEE 1800-2017 Annex H open-array packed-element copy API.
// Exercises scalar and canonical vector access, 2/4-state elements,
// packed elements wider than one DPI word, and a multidimensional array.
module m10_dpi_open_array_copy_api_test;
  import "DPI-C" function int c_dpi_open_array_copy_api(
      inout bit          bits[],
      inout logic        logic_bits[],
      inout bit   [7:0]  bytes[],
      inout bit   [39:0] wide[],
      inout logic [3:0]  logic_words[],
      inout bit   [7:0]  matrix[][]);

  bit          bits[];
  logic        logic_bits[];
  bit   [7:0]  bytes[];
  bit   [39:0] wide[];
  logic [3:0]  logic_words[];
  bit   [7:0]  matrix[][];
  int status;

  initial begin
    bits = new[2];
    bits[0] = 0;
    bits[1] = 1;

    logic_bits = new[2];
    logic_bits[0] = 1'bz;
    logic_bits[1] = 1'bx;

    bytes = new[3];
    bytes[0] = 8'h12;
    bytes[1] = 8'h34;
    bytes[2] = 8'h56;

    wide = new[1];
    wide[0] = 40'h12_3456_789a;

    logic_words = new[1];
    logic_words[0] = 4'b1xz0;

    matrix = new[2];
    for (int i = 0; i < 2; i++) begin
      bit [7:0] row[];
      row = new[2];
      row[0] = 8'h31 + 8'h10 * i;
      row[1] = 8'h32 + 8'h10 * i;
      matrix[i] = row;
    end

    status = c_dpi_open_array_copy_api(bits, logic_bits, bytes, wide,
                                       logic_words, matrix);

    if (status == 0 &&
        bits[0] === 1'b1 && bits[1] === 1'b0 &&
        logic_bits[0] === 1'bx && logic_bits[1] === 1'bz &&
        bytes[0] == 8'h12 && bytes[1] == 8'ha5 && bytes[2] == 8'h5a &&
        wide[0] == 40'h55_89ab_cdef &&
        logic_words[0] === 4'b0xz1 &&
        matrix[0][0] == 8'he1 && matrix[0][1] == 8'h32 &&
        matrix[1][0] == 8'h41 && matrix[1][1] == 8'he2)
      $display("PASS m10_dpi_open_array_copy_api_test");
    else
      $display("FAIL m10_dpi_open_array_copy_api_test status=%0h", status);
    $finish;
  end
endmodule
