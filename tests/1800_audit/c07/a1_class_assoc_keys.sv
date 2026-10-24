class K; endclass
module a1_class_assoc_keys;
  int ak[K];
  K k1, k2;
  initial begin
    $display("BEGIN a1"); $fflush;
    k1 = new; k2 = new; ak[k1] = 1; ak[k2] = 2;
    $display("A1 %0d %0d %0d", ak.size(), ak[k1], ak[k2]);
  end
endmodule
