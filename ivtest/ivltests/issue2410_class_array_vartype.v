class holder;
  logic [7:0] ov[0:3];
endclass

module issue2410_class_array_vartype;
  holder hs[2];

  initial begin
    hs[0] = new;
    hs[1] = new;
    hs[1].ov[0] = 8'h11;
    hs[1].ov[1] = 8'h22;
    hs[1].ov[2] = 8'h33;
    hs[1].ov[3] = 8'h44;
    hs[1].ov[1:2] = '{hs[1].ov[2], hs[1].ov[1]};
    if (hs[1].ov[1] !== 8'h33 || hs[1].ov[2] !== 8'h22)
      $fatal(1, "class property array slice mismatch");
    $display("PASSED");
    $finish;
  end
endmodule
