module issue3835;
  logic [1:0][1:0] m[0:1];
  assign m[1][1] = 2'b10;

  int pos = 0;
  initial begin
    m[0][0][pos +: 1] = 1'b1;
    #1;
    if (m[0][0][0] !== 1'b1 || m[1][1] !== 2'b10)
      $fatal(1, "wrong low bit or continuously driven lane");

    // m[0][1][1] is bit 3 of the four-bit word.
    pos = 1;
    m[0][1][pos +: 1] = 1'b1;
    if (m[0][1][1] !== 1'b1)
      $fatal(1, "blocking write to bit 3 was lost");

    m[0][1][pos +: 1] <= 1'b0;
    if (m[0][1][1] !== 1'b1)
      $fatal(1, "nonblocking write changed bit 3 early");
    #1;
    if (m[0][1][1] !== 1'b0 || m[0][0][0] !== 1'b1 || m[1][1] !== 2'b10)
      $fatal(1, "wrong array values after nonblocking write");
    $display("PASSED");
  end
endmodule
