interface class IA #(type T1 = logic);
  typedef T1 [1:0] T2;
  pure virtual function T2 fa();
endclass

module p08_23_scope_type_s2;
  IA#(bit)::T2 v2;
  initial begin
    v2 = 2'b10;
    $display("S2 %0d %0d", $bits(v2), v2);
  end
endmodule
