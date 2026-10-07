`define MULTILINE """first
middle "quote // stays in the string
last"""
`define CONTINUED """foo\
bar"""

module main;
  string multiline;
  string continued;

  initial begin
    multiline = `MULTILINE;
    continued = `CONTINUED;
    if (multiline != "first\nmiddle \"quote // stays in the string\nlast")
      $fatal(1, "triple-quoted string mismatch: %s", multiline);
    if (continued != "foobar")
      $fatal(1, "escaped newline mismatch: %s", continued);
    $display("PASSED");
  end
endmodule
