`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    logic [3:0] tag;
    logic       valid;
  } entry_t;

  localparam int     Zeros[31:0] = '{default: 0};
  localparam integer Sevens[1:4] = '{default: 7};
  localparam entry_t Entries[2][3:1] =
      '{default: '{tag: 4'ha, valid: 1'b1}};

  initial begin
    if (Zeros[0] !== 0 || Zeros[17] !== 0 || Zeros[31] !== 0 ||
        Sevens[1] !== 7 || Sevens[4] !== 7 ||
        Entries[0][3] !== 5'b10101 || Entries[1][1] !== 5'b10101) begin
      $display("FAILED -- unpacked parameter default assignment pattern");
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
