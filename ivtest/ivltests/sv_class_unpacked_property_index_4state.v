module sv_class_unpacked_property_index_4state;
  class matrix_t;
    logic [7:0] values [1:0];

    function new();
      values[1] = 8'h13;
      values[0] = 8'h03;
    endfunction
  endclass

  logic [1:0] patterns [0:15];
  matrix_t matrix;
  bit malformed;
  logic [7:0] expected, actual;

  initial begin
    patterns[0] = 2'b00; patterns[1] = 2'b01;
    patterns[2] = 2'b10; patterns[3] = 2'b11;
    patterns[4] = 2'b0x; patterns[5] = 2'b0z;
    patterns[6] = 2'bx0; patterns[7] = 2'bx1;
    patterns[8] = 2'bxz; patterns[9] = 2'bz0;
    patterns[10] = 2'bz1; patterns[11] = 2'bzx;
    patterns[12] = 2'bxx; patterns[13] = 2'bzz;
    patterns[14] = 2'b1x; patterns[15] = 2'b1z;
    matrix = new;
    malformed = $test$plusargs("MALFORMED");

    for (int idx = 0; idx < 16; idx++) begin
      expected = 8'hxx;
      if (!malformed)
        case (patterns[idx])
          2'd0: expected = 8'h03;
          2'd1: expected = 8'h13;
          default: ;
        endcase
      actual = matrix.values[patterns[idx]];
      if (actual !== expected)
        $fatal(1, "index pattern %b: got %h expected %h",
               patterns[idx], actual, expected);
    end

    $display("PASSED");
  end
endmodule
