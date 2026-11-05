module issue2486_class_property_packed_incdec;
  class C;
    logic [3:0][7:0] a [2];
  endclass

  C h;
  logic [3:0] r;
  int i = 1, j = 1, k = 4;

  initial begin
    h = new;
    h.a[1] = 32'haabbccdd;
    r = --h.a[i][j][k+:4];
    if (r !== 4'hb || h.a[1] !== 32'haabbbcdd)
      $fatal(1, "variable nested property decrement failed: %h %h", r, h.a[1]);
    $display("PASSED");
  end
endmodule
