module sv_assoc_nonintegral_query;
  int aa[string];
  initial begin
    $display("%0d", $left(aa));
    $display("%0d", $right(aa));
    $display("%0d", $low(aa));
    $display("%0d", $high(aa));
    $display("%0d", $increment(aa));
    $display("%0d", $size(aa));
  end
endmodule
