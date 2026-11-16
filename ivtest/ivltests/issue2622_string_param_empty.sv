// IEEE 1800-2023 6.16: a string literal converted to the string type drops
// every "\0" character, and "" is the empty string, so %s of a string
// parameter set to "" prints nothing. A vector string literal keeps its
// NUL byte.
module tb;
  parameter string EMPTY = "";
  localparam string E2 = "";
  localparam string NUL_IN = "a\0b";
  parameter string NE = "ab";
  initial begin
    $display("[%s] %0d [%s] %0d [%s] %0d [%s] %0d", EMPTY, EMPTY.len(),
             E2, E2.len(), NUL_IN, NUL_IN.len(), NE, NE.len());
    $display("vec=%0d", $bits(""));
  end
endmodule
