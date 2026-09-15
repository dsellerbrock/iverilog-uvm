module sv_const_string_substr_bounds;
  function automatic string slice(input string text,
                                  input logic [127:0] first,
                                  input logic [127:0] last);
    return text.substr(first, last);
  endfunction
  function automatic string signed_slice(input string text,
                                         input logic signed [127:0] first,
                                         input logic signed [127:0] last);
    return text.substr(first, last);
  endfunction

  localparam string EMPTY = slice("", 0, 0);
  localparam string NEGATIVE = signed_slice("ABC", -1, 1);
  localparam string REVERSED = slice("ABC", 2, 1);
  localparam string AT_END = slice("ABC", 0, 3);
  localparam string UNKNOWN = slice("ABC", 128'bx, 0);
  localparam string Z_INDEX = slice("ABC", 128'bz, 0);
  localparam string MIXED_X = slice("ABCDE", {{126{1'b0}}, 2'b1x}, 2);
  localparam string WIDE = slice("ABC", 128'h1_0000000000000000000000000, 0);

  initial begin
    if (EMPTY != "" || NEGATIVE != "" || REVERSED != "" || AT_END != "" ||
        UNKNOWN != "A" || Z_INDEX != "A" || MIXED_X != "C" || WIDE != "A")
      $fatal(1, "substr boundary/index conversion mismatch");
    $display("PASSED");
  end
endmodule
