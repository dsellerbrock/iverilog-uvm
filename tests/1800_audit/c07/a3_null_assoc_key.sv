class K; endclass
module a3_null_assoc_key;
  int ak[K];
  K k1, k2;
  initial begin
    $display("BEGIN a3"); $fflush;
    k1 = new; k2 = new; ak[k1] = 1; ak[k2] = 2; ak[null] = 4;
    $display("A3 %0d %0d", ak.exists(null), ak[null]);
  end
endmodule
