class matrix_t;
  logic [7:0] values [1:0];

  function new();
    values[1] = 8'h13;
    values[0] = 8'h03;
  endfunction
endclass

module prop_index_check_predecode;
  logic [1:0] patterns [0:15];
  matrix_t matrix;
  bit malformed;
  int errors = 0;
  logic [7:0] expected;
  logic [7:0] actual;

  initial begin
    patterns[0] = 2'b00;
    patterns[1] = 2'b01;
    patterns[2] = 2'b10;
    patterns[3] = 2'b11;
    patterns[4] = 2'b0x;
    patterns[5] = 2'b0z;
    patterns[6] = 2'bx0;
    patterns[7] = 2'bx1;
    patterns[8] = 2'bxz;
    patterns[9] = 2'bz0;
    patterns[10] = 2'bz1;
    patterns[11] = 2'bzx;
    patterns[12] = 2'bxx;
    patterns[13] = 2'bzz;
    patterns[14] = 2'b1x;
    patterns[15] = 2'b1z;
    matrix = new;
    malformed = $test$plusargs("MALFORMED");

    for (int i = 0; i < 16; i++) begin
      expected = 8'hxx;
      if (!malformed) begin
        case (patterns[i])
          2'd1: expected = 8'h13;
          2'd0: expected = 8'h03;
          default: expected = 8'hxx;
        endcase
      end

      actual = matrix.values[patterns[i]];
      if (actual !== expected) begin
        $display("FAIL case=%0d got=%h expected=%h", i, actual, expected);
        errors++;
      end
    end

    if (errors != 0)
      $fatal(1, "property-index cases failed: %0d", errors);
    if (malformed)
      $display("PASS property-index malformed metadata (16 cases)");
    else
      $display("PASS property-index 4-state patterns (16 cases)");
    $finish;
  end
endmodule
