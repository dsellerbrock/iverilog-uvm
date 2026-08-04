`begin_keywords "1800-2012"

module main;
  typedef logic [31:0] word_t;

  // Concatenated string literals are a constant packed bit sequence when a
  // packed integral parameter provides the assignment context.
  localparam word_t [2:0] Names = {
    "ABCD",
    "EFGH",
    "IJKL"
  };

  initial begin
    if (Names[2] !== 32'h41424344 ||
        Names[1] !== 32'h45464748 ||
        Names[0] !== 32'h494a4b4c) begin
      $display("FAILED -- packed string table was %h", Names);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
