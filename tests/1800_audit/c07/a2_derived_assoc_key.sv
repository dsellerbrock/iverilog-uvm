class K; endclass
class KD extends K; endclass
module a2_derived_assoc_key;
  int ak[K];
  K k1, k2;
  KD kd;
  initial begin
    $display("BEGIN a2"); $fflush;
    k1 = new; k2 = new; kd = new;
    ak[k1] = 1; ak[k2] = 2; ak[kd] = 3;
    $display("A2 %0d %0d", ak[kd], ak.size());
  end
endmodule
