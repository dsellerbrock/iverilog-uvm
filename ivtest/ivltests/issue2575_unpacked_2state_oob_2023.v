module issue2575_unpacked_2state_oob;
  bit [7:0] bm[4];
  logic [7:0] lm[4];
  int i;

  initial begin
    foreach (bm[k]) begin
      bm[k] = 8'h11;
      lm[k] = 8'h22;
    end

    i = 7;
    if (bm[7] !== 8'h00 || bm[i] !== 8'h00)
      $fatal(1, "2-state out-of-bounds read did not return zero");
    if (lm[7] !== 8'hxx || lm[i] !== 8'hxx)
      $fatal(1, "4-state out-of-bounds read did not return X");

    $display("PASSED");
    $finish;
  end
endmodule
