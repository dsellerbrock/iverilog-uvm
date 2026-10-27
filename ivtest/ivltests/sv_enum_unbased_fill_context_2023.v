module main;
  enum integer { IDLE = 0, XX = 'x, S1 = 'b01, S2 = 'b10 } state;
  enum logic [7:0] { BYTE_X = 'x, BYTE_Z = 'z } byte_state;

  initial begin
    if (XX !== 32'bx)
      $fatal(1, "integer enum x was %b", XX);
    if (BYTE_X !== 8'bx)
      $fatal(1, "packed enum x was %b", BYTE_X);
    if (BYTE_Z !== 8'bz)
      $fatal(1, "packed enum z was %b", BYTE_Z);
    $display("PASSED");
    $finish;
  end
endmodule
