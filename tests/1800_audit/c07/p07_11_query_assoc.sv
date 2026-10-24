module p07_11_query_assoc;
  int aa[int]; int ae[int];
  initial begin
    aa[5] = 1; aa[9] = 2;
    $display("A %0d %0d %0d %0d %0d %0d %b", $left(aa), $right(aa), $low(aa), $high(aa), $increment(aa), $size(aa), $low(ae));
  end
endmodule
