module issue3806_string_literal_format;
  localparam EMPTY = "";
  logic [31:0] packed_zero = 0;
  string formatted;

  initial begin
    $display("literal [%s]", "");
    $display("parameter [%s]", EMPTY);
    $display("adjacent [%s%s]", "", "x");
    $display("concat [%s]", {"", "ab"});
    $display("leading NUL [%s]", "\0ab");
    $display("leading space [%s]", "\000\000 ab");
    formatted = $sformatf("[%s]", "");
    $display("formatted %s len=%0d", formatted, formatted.len());
    $display("packed zero [%s]", packed_zero);
    $display("zero width [%0s]", "");
    $display("explicit width [%4s] [%-4s]", "\0ab", "\0ab");
  end
endmodule
